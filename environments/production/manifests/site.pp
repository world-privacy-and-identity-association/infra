node  cassiopeia {
  include container::contained
if $signerLocation == 'self' {
  include container::no_ssh
} else {
  include container::ssh
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
  } ->
  package { 'wpia-cassiopeia-signer':
    ensure => 'installed',
    require => Exec['apt_update']
  }
if $signerLocation == 'self' {
  package { 'tcpserial':
    ensure => 'installed',
    require => Exec['apt_update']
  }
  $cass_ip='';
  file {'/etc/systemd/system/tcpserial.service':
    ensure => 'file',
    content => epp('gigi/tcpserial'),
    require => Package['tcpserial']
  }->
  service{'tcpserial.service':
    ensure => 'running',
    enable => true,
    provider => 'systemd',
    before => Service['cassiopeia-signer.service']
  }
} elsif  $signerLocation == '/dev/ttyS0' {
  exec {'/bin/mknod /dev/ttyS0 c 4 64':
    creates => "/dev/ttyS0",
    before => Service['cassiopeia-signer.service']
  }
} else {
  fail("unknown signerLocation")
}
  file {'/var/lib/cassiopeia/':
    ensure => 'directory',
  }->
  exec {'/usr/bin/openssl dhparam -out dh_param.pem 2048':
    timeout => '0',
    creates => '/var/lib/cassiopeia/dh_param.pem',
    cwd => '/var/lib/cassiopeia/',
    require => File['/var/lib/cassiopeia/']
  } # TODO: make this unneded and fix cassiopeia dh-param-generation

  file {'/var/lib/cassiopeia/logs':
    ensure => 'directory',
  }

  file {'/var/lib/cassiopeia/profiles':
    ensure => 'directory',
    source => 'puppet:///modules/cassiopeia_signer/profiles',
    recurse => true,
    purge => true
  }
  file {'/var/lib/cassiopeia/ca':
    ensure => 'directory',
    source => 'puppet:///modules/cassiopeia_signer/ca',
    recurse => true,
  }

  file {'/var/lib/cassiopeia/keys':
    ensure => 'directory',
    require => File['/var/lib/cassiopeia/']
  }
  file {'/var/lib/cassiopeia/keys/ca.crt':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/ca.crt',
  }
  file {'/var/lib/cassiopeia/keys/signer_server.crt':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/signer_server.crt',
  }
  file {'/var/lib/cassiopeia/keys/signer_server.key':
    ensure => 'file',
    source => 'puppet:///modules/cassiopeia/signer_server.key',
  }
  $gigi_pg_ip=""
  $gigi_pg_password=""
  file {'/var/lib/cassiopeia/config.txt':
    ensure => 'file',
    content => epp('gigi/cassiopeia-client-conf'),
  }

  file {'/etc/systemd/system/cassiopeia-signer.service':
    ensure => 'file',
    source => 'puppet:///modules/gigi/cassiopeia-signer.service',
  }->
  service{'cassiopeia-signer.service':
    ensure => 'running',
    enable => true,
    provider => 'systemd',
    require => [Exec['/usr/bin/openssl dhparam -out dh_param.pem 2048'],
                Package['wpia-cassiopeia-signer'],
                File['/var/lib/cassiopeia/logs'],
                File['/var/lib/cassiopeia/profiles'],
                File['/var/lib/cassiopeia/ca'],
                File['/var/lib/cassiopeia/config.txt'],
                File['/var/lib/cassiopeia/keys/ca.crt'],
                File['/var/lib/cassiopeia/keys/signer_server.crt'],
                File['/var/lib/cassiopeia/keys/signer_server.key']]
  }

}


node exim{
  include container::contained;
  include container::no_ssh;

  package{ 'exim4-daemon-light':
    ensure => 'installed'
  } ->
  file{ '/etc/exim4/update-exim4.conf.conf':
    ensure => 'file',
    content => epp('exim/update-exim4.conf.conf'),
    notify => Exec['/usr/sbin/update-exim4.conf']
  }
  exec{ '/usr/sbin/update-exim4.conf':
    refreshonly => 'true',
    notify => Service['exim4']
  }
  service{ 'exim4':
    ensure => 'running',
    enable => true,
  }
}
