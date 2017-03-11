class my_fw::post {
  package { 'iptables-persistent':
    ensure => 'installed'
  }
  resources { 'firewall':
      purge => true,
  }
  Package['iptables-persistent'] ->
  firewall { '80 dnat':
    proto  => 'tcp',
    dport  => '80',
    jump => 'DNAT',
    todest => "${$ips[front-nginx]}:80",
    iniface => $internet_iface,
    table    => 'nat',
    chain    => 'PREROUTING',
  } ->
  firewall { '80 dnat-https':
    proto  => 'tcp',
    dport  => '443',
    jump => 'DNAT',
    todest => "${$ips[front-nginx]}:443",
    iniface => $internet_iface,
    table    => 'nat',
    chain    => 'PREROUTING',
  } ->
  firewall { '80 dnat-git':
    proto  => 'tcp',
    dport  => '9418',
    jump => 'DNAT',
    todest => "${$ips[gitweb]}:9418",
    iniface => $internet_iface,
    table    => 'nat',
    chain    => 'PREROUTING',
  } ->
  firewall { '80 dnat-htop-ssh':
    proto  => 'tcp',
    dport  => '2222',
    jump => 'DNAT',
    todest => "${$ips[hop]}:22",
    iniface => $internet_iface,
    table    => 'nat',
    chain    => 'PREROUTING',
  } ->
  firewall { '80 MASQ':
    chain => 'POSTROUTING',
    table => 'nat',
    jump => 'MASQUERADE',
    proto => 'all',
    outiface => $internet_iface,
    source => '10.0.3.0/24',
  }
}


node host01 {
    include my_fw::post
    include lxc
    package {'bridge-utils':
        ensure => 'installed'
    } -> file {'/etc/network/interfaces.d/lxcbr0':
        source => 'puppet:///modules/lxc/lxcbr0'
    } -> exec {'ifup lxcbr0':
      command => '/sbin/ifdown lxcbr0; /sbin/ifup lxcbr0',
      refreshonly => true,
      subscribe => File['/etc/network/interfaces.d/lxcbr0']
    } -> exec { "enable forwarding on $hostname":
      user    => "root",
      command => "/bin/echo 1 > /proc/sys/net/ipv4/ip_forward",
      unless  => "/bin/grep -q 1 /proc/sys/net/ipv4/ip_forward";
    }->
      file_line {"root-resolv1":
      path   => "/etc/resolv.conf",
      ensure => 'absent',
      match_for_absence => "true",
      match  => '^domain ',
      line   => ''
    }->
      file_line {"root-resolv2":
      path   => "/etc/resolv.conf",
      ensure => 'absent',
      match_for_absence => "true",
      match  => '^search ',
      line   => ''
    }
if $signerLocation == 'self' {
    exec {"create cassiopeia-comm-keys":
      command => '/etc/puppet/code/modules/cassiopeia/mkcassiopeia',
      creates => '/etc/puppet/code/modules/cassiopeia/files/signer_client.crt'
    }
} else {
    exec {"create cassiopeia-comm-keys":
      command => '/bin/false',
      creates => '/etc/puppet/code/modules/cassiopeia/files/signer_client.crt'
    }
}
    exec {"gigi keystore.pkcs12":
      command => '/bin/bash -c \'keystorepw=$(/usr/bin/head -c 15 /dev/urandom | base64); /usr/bin/openssl pkcs12 -export -name "mail" -in /etc/puppet/code/modules/gigi/files/client.crt -inkey /etc/puppet/code/modules/gigi/client.key -CAfile /etc/puppet/codemodules/nre/files/config/ca/root.crt -password file:<(echo $keystorepw) > /etc/puppet/code/modules/gigi/files/keystore.pkcs12; /usr/bin/printf "%s" "$keystorepw" > /etc/puppet/code/modules/gigi/files/keystorepw\'',
      unless => '/usr/bin/[  /etc/puppet/code/modules/gigi/files/keystore.pkcs12 -nt /etc/puppet/code/modules/gigi/files/client.crt ] || ! /usr/bin/[ -f /etc/puppet/code/modules/gigi/files/client.crt ]'
    }
    lxc::container { 'front-nginx':
        contname => 'front-nginx',
        ip => $ips[front-nginx],
        dir => ["/data", "/data-crl", '/data-crl-gigi', '/gitweb-socket', '/srv/git'],
        bind => {
          "/data/nginx" => {target => "data", option => ",ro"},
          "/data/crl" => {target => "data-crl", option => ",ro"},
          "/data/gigi-crl" => {target => "data-crl-gigi", option => ",ro"},
          "/run/gitweb-socket" => {target => 'gitweb-socket'},
          "/data/git" => { 'target' => "srv/git", option => ",ro"}
        },
        require => File['/data/nginx', '/data/crl/htdocs', '/data/gigi-crl']
    }
    file { '/data':
       ensure => 'directory',
    }
    file { '/data/nginx':
      ensure => 'directory',
    }
    file { '/data/crl':
      ensure => 'directory',
      owner => $administrativeUser
    }
    file { '/data/git':
      ensure => 'directory',
      owner => $administrativeUser,
    }
    file { '/data/gigi-crl':
      ensure => 'directory',
      owner => $administrativeUser
    }
    file { '/data/crl/htdocs':
      ensure => 'directory',
      owner => $administrativeUser
    }
    file { '/data/postgres/conf':
      ensure => 'directory',
    }
    file { '/data/postgres/data':
      ensure => 'directory',
    }
    file { '/data/postgres':
      ensure => 'directory',
    }
    file { '/data/gigi':
      ensure => 'directory',
    }
    lxc::container { 'postgres-primary':
        contname => 'postgres-primary',
        ip => $ips[postgres],
        dir => ["/var/lib/postgresql", "/etc/postgresql"],
        bind => {
          "/data/postgres/data" => { target => "var/lib/postgresql"},
          "/data/postgres/conf" => { target => "etc/postgresql"}
        },
        require => File['/data/postgres']
    }
    $gigi_serial_conf= $signerLocation ? {
      'self'          => [],
      '/dev/ttyS0'    => ["lxc.cgroup.devices.allow = c 4:64 rwm"]
    }

    lxc::container { 'gigi':
        contname => 'gigi',
        ip => $ips[gigi],
        dir => ["/var/lib/wpia-gigi", "/var/lib/wpia-gigi/keys", '/var/lib/cassiopeia', '/var/lib/cassiopeia/ca'],
        bind => {
          "/data/gigi" => { target => "var/lib/wpia-gigi/keys"},
          "/data/gigi-crl" => { target => "var/lib/cassiopeia/ca"}
        },
        confline => $gigi_serial_conf,
        require => File['/data/gigi', '/data/gigi-crl']
    }
    if $signerLocation == 'self' {
      lxc::container { 'cassiopeia':
        contname => 'cassiopeia',
        ip => $ips[cassiopeia]
      }
    }
    lxc::container { 'exim':
        contname => 'exim',
        ip => $ips[exim]
    }
    lxc::container { 'hop':
        contname => 'hop',
        ip => $ips[hop]
    }
    lxc::container { 'quiz':
        contname => 'quiz',
        ip => $ips[quiz]
    }
    file{'/run/gitweb-socket':
        ensure => 'directory'
    }
    lxc::container { 'gitweb':
        require => File['/data/git', '/run/gitweb-socket'],
        contname => 'gitweb',
        dir => ['/gitweb-socket', '/srv/git'],
        bind => {
          "/run/gitweb-socket" => { 'target' => "gitweb-socket"},
          "/data/git" => { 'target' => "srv/git", option => ",ro"}
        },
        ip => $ips[gitweb]
    }
    # Required for bootstrap-user
    package {'acl':
        ensure => 'installed'
    }
}

