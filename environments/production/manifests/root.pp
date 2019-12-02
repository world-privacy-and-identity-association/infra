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
  firewall {'80 dnatv6':
    provider => 'ip6tables',
    proto  => 'tcp',
    dport => '80',
    jump => 'DNAT',
    todest => "[${$ipsv6[front-nginx]}]:80",
    iniface => $internet_iface,
    table => 'nat',
    chain => 'PREROUTING'
  } ->
  firewall {'80 dnatv6-https':
    provider => 'ip6tables',
    proto  => 'tcp',
    dport => '443',
    jump => 'DNAT',
    todest => "[${$ipsv6[front-nginx]}]:443",
    iniface => $internet_iface,
    table => 'nat',
    chain => 'PREROUTING'
  } ->
  firewall {'80 dnatv6-hop-ssh':
    provider => 'ip6tables',
    proto  => 'tcp',
    dport => '2222',
    jump => 'DNAT',
    todest => "[${$ipsv6[hop]}]:22",
    iniface => $internet_iface,
    table => 'nat',
    chain => 'PREROUTING'
  } ->
  firewall {'80 MASQ-v6':
    provider => 'ip6tables',
    chain => 'POSTROUTING',
    table => 'nat',
    proto  => 'all',
    jump => 'MASQUERADE',
    source => "[fc00:1::]/64",
    outiface => $internet_iface,
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
    exec { "enable forwarding on $hostname":
      user    => "root",
      command => "/bin/echo 1 > /proc/sys/net/ipv4/ip_forward",
      unless  => "/bin/grep -q 1 /proc/sys/net/ipv4/ip_forward",
      require => Class['lxc']
    } -> exec { "enable v6 forwarding on $hostname":
      user    => "root",
      command => "/bin/echo 1 > /proc/sys/net/ipv6/conf/all/forwarding",
      unless  => "/bin/grep -q 1 /proc/sys/net/ipv6/conf/all/forwarding"
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
        require => File['/data/crl/htdocs']
    }
    lxc::container_bind{ '/data/nginx':
      container => 'front-nginx',
      target => 'data',
      option => ',ro'
    }
    lxc::container_bind{ '/data/crl':
      container => 'front-nginx',
      target => 'data-crl',
      option => ',ro'
    }
    lxc::container_bind{ '/data/gigi-crl':
      container => 'front-nginx',
      target => 'data-crl-gigi',
      option => ',ro'
    }
    lxc::container_bind{ '/run/gitweb-socket':
      container => 'front-nginx',
      target => 'gitweb-socket',
    }
    lxc::container_bind{ '/run/git-smart-http-socket':
      container => 'front-nginx',
      target => 'git-smart-http-socket',
    }
    lxc::container_bind{ '/data/git':
      container => 'front-nginx',
      target => 'srv/git',
      option => ',ro'
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
    File <| tag == root |>
    Lxc::Container <| tag == root |>
    Lxc::Container_bind <| tag == root |>
    file{'/run/gitweb-socket':
        ensure => 'directory'
    }
    file{'/run/git-smart-http-socket':
        ensure => 'directory'
    }
    lxc::container { 'gitweb':
        contname => 'gitweb',
        dir => ['/gitweb-socket', '/git-smart-http-socket', '/srv/git'],
        bind => {
          "/run/gitweb-socket" => { 'target' => "gitweb-socket"},
          "/run/git-smart-http-socket" => { 'target' => "git-smart-http-socket"},
          "/data/git" => { 'target' => "srv/git", option => ",ro"}
        },
        ip => $ips[gitweb]
    }
    # Required for bootstrap-user
    package {'acl':
        ensure => 'installed'
    }
}

