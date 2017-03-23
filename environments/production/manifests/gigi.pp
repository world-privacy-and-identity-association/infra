node gigi {
  include container::contained;
  include container::no_ssh;

  file { "${::puppet_vardir}/debconf/":
     ensure => 'directory'
  }
  $gigi_pkg = $testServer ? {
    'true' => 'wpia-gigi-testing',
    default => 'wpia-gigi'
  }
  file { "${::puppet_vardir}/debconf/gigi-lang.debconf":
     ensure => 'present',
     content => "$gigi_pkg     $gigi_pkg/fetch-locales-command       string  gigi fetch-locales $gigi_translation"
  } ->
  exec { 'debconf-gigi':
    path => "/usr/bin",
    command => "/usr/bin/debconf-set-selections < ${::puppet_vardir}/debconf/gigi-lang.debconf",
    unless => "/usr/bin/debconf-get-selections | /bin/grep -F '$gigi_translation' | /bin/grep -F '$gigi_pkg/fetch-locales'"
  }

  class{'apt':}
  apt_key{ 'E643C483A426BB5311D26520A631B6AF9FD3DF94':
    source => 'http://deb.dogcraft.de/signer.gpg',
    ensure => 'present'
  } ->
  file { '/etc/apt/sources.list.d/dogcraft.list':
    source => 'puppet:///modules/lxc/dogcraft.list',
    ensure => 'present',
    notify => Exec['apt_update']
  }
  package { $gigi_pkg:
    require => [Exec['debconf-gigi'],Exec['apt_update']],
    ensure => 'installed',
  }
  $gigi_pg_ip = $ips[postgres];
  $gigi_pg_password = $passwords[postgres][gigi];
  file { '/var/lib/wpia-gigi':
    ensure => 'directory'
  }
  file { '/var/lib/wpia-gigi/config':
    ensure => 'directory'
  }
  file {'/var/lib/wpia-gigi/config/gigi.properties':
    ensure => 'file',
    content => epp('gigi/gigi.properties')
  }
  file {'/var/lib/wpia-gigi/config/ca':
    ensure => 'directory',
    source => 'puppet:///modules/nre/config/ca',
    recurse => true,
    purge => true,
    notify => Exec['keytool for /var/lib/wpia-gigi/config/cacerts.jks']
  }
  file {'/var/lib/wpia-gigi/config/profiles':
    ensure => 'directory',
    source => 'puppet:///modules/nre/config/profiles',
    recurse => true,
    purge => true,
  }
  exec {'keytool for /var/lib/wpia-gigi/config/cacerts.jks':
    cwd => '/var/lib/wpia-gigi/config/ca',
    refreshonly => true,
    require => Package[$gigi_pkg],
    command => '/bin/rm -f ../cacerts.jks && /usr/bin/keytool -importcert -keystore ../cacerts.jks -noprompt -storepass changeit -file root.crt -alias root && for i in assured.crt codesign.crt env.crt orga.crt orgaSign.crt unassured.crt *_*.crt; do /usr/bin/keytool -importcert -keystore ../cacerts.jks -storepass changeit -file "$i" -alias "${i%.crt}"; done',
  }
  file {'/var/lib/wpia-gigi/config/truststorepw':
    ensure => 'file',
    content => 'changeit',
  }
  file {['/etc/wpia','/etc/wpia/gigi']:
    ensure => 'directory'
  }
  file {'/var/lib/wpia-gigi/config/keystore.pkcs12':
    source => ['puppet:///modules/gigi/keystore.pkcs12', 'puppet:///modules/gigi/empty'],
    notify => Exec['tar for gigi-conf']
  }->
  file {'/var/lib/wpia-gigi/config/keystorepw':
    source => ['puppet:///modules/gigi/keystorepw', 'puppet:///modules/gigi/empty'],
    show_diff => 'no',
    notify => Exec['tar for gigi-conf']
  }
  exec{'tar for gigi-conf':
    command => 'if /usr/bin/[ -s /var/lib/wpia-gigi/config/keystore.pkcs12 ]; then /bin/tar cf /etc/wpia/gigi/conf.tar gigi.properties truststorepw cacerts.jks keystorepw keystore.pkcs12; else /bin/tar cf /etc/wpia/gigi/conf.tar gigi.properties truststorepw cacerts.jks; fi',
    provider => 'shell',
    path => '',
    cwd => '/var/lib/wpia-gigi/config',
    unless => '/usr/bin/[ /var/lib/wpia-gigi/keys/keystore.pkcs12 -ot /etc/wpia/gigi/conf.tar ] && /usr/bin/[ /var/lib/wpia-gigi/config/cacerts.jks -ot /etc/wpia/gigi/conf.tar ] && /usr/bin/[ /var/lib/wpia-gigi/config/gigi.properties -ot /etc/wpia/gigi/conf.tar ]',
    subscribe => [File['/var/lib/wpia-gigi/config/truststorepw'],Exec['keytool for /var/lib/wpia-gigi/config/cacerts.jks'],File['/var/lib/wpia-gigi/config/gigi.properties']],
    require => File['/etc/wpia/gigi']
  }
  file {'/var/lib/wpia-gigi/keys/crt':
    ensure => 'directory',
    owner => 'gigi',
    require => Package[$gigi_pkg]
  }
  file {'/var/lib/wpia-gigi/keys/csr':
    ensure => 'directory',
    owner => 'gigi',
    require => Package[$gigi_pkg]
  }
  exec {'/gigi-ready':
    creates => '/gigi-ready',
    command =>'/bin/false',
    require => Exec['tar for gigi-conf']
  }
  exec{'alexa':
    command => '/usr/bin/gigi fetch-alexa /var/lib/wpia-gigi/blacklist.dat 100',
    creates => '/var/lib/wpia-gigi/blacklist.dat',
    require => [File['/var/lib/wpia-gigi'],Package[$gigi_pkg]]
  } -> service{'gigi-proxy.socket':
    ensure => 'running',
    enable => true,
    provider => 'systemd',
    subscribe => [Exec['tar for gigi-conf'],File['/var/lib/wpia-gigi/config/profiles']],
    require => [Package[$gigi_pkg], File['/var/lib/wpia-gigi/keys/crt'], File['/var/lib/wpia-gigi/keys/csr'], Exec['/gigi-ready']]
  }
  package{'cacert-cassiopeia':
    ensure => 'installed',
    require => Exec['apt_update']
  }
if $signerLocation == 'self' {
  package { 'tcpserial':
    ensure => 'installed',
    require => Exec['apt_update']
  }
  $cass_ip = $ips[cassiopeia]
  file {'/etc/systemd/system/tcpserial.service':
    ensure => 'file',
    content => epp('gigi/tcpserial'),
    require => Package['tcpserial']
  }->
  service{'tcpserial.service':
    ensure => 'running',
    enable => true,
    provider => 'systemd',
    before => Service['cassiopeia-client.service']
  }
} elsif  $signerLocation == '/dev/ttyS0' {
  exec {'/bin/mknod /dev/ttyS0 c 4 64':
    creates => "/dev/ttyS0",
    before => Service['cassiopeia-client.service']
  }
}

  file {'/var/lib/cassiopeia/':
    ensure => 'directory',
    require => Package['cacert-cassiopeia']
  }
  file {'/var/lib/cassiopeia/config.txt':
    ensure => 'file',
    content => epp('gigi/cassiopeia-client-conf')
  }

  file {'/var/lib/cassiopeia/logs':
    ensure => 'directory',
  }

  file {'/var/lib/cassiopeia/profiles':
    ensure => 'directory',
    source => 'puppet:///modules/cassiopeia_client/profiles',
    recurse => true,
    purge => true
  }
  file {'/var/lib/cassiopeia/ca':
    ensure => 'directory',
    source => 'puppet:///modules/cassiopeia_client/ca',
    recurse => true,
  }

  file {'/var/lib/cassiopeia/keys':
    ensure => 'directory',
    require => File['/var/lib/cassiopeia/']
  }
  file {'/var/lib/cassiopeia/keys/ca.crt':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/ca.crt'
  }
  file {'/var/lib/cassiopeia/keys/signer_client.crt':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/signer_client.crt'
  }
  file {'/var/lib/cassiopeia/keys/signer_client.key':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/signer_client.key'
  }

  file { '/etc/systemd/system/cassiopeia-client.service':
    source => 'puppet:///modules/gigi/cassiopeia-client.service',
    ensure => 'present'
  } ->
  service{'cassiopeia-client.service':
    provider => 'systemd',
    require => [File['/var/lib/cassiopeia/config.txt'],
            File['/var/lib/cassiopeia/ca'],
            File['/var/lib/cassiopeia/logs'],
            File['/var/lib/cassiopeia/profiles'],
            File['/var/lib/cassiopeia/keys/ca.crt'],
            File['/var/lib/cassiopeia/keys/signer_client.crt'],
            File['/var/lib/cassiopeia/keys/signer_client.key'],
            Exec['/gigi-ready']],
    ensure => 'running',
    enable => true,
  }

}
