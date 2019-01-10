define motion::virtual ($domain = "motion.${systemDomain}", $container = $name) {
  @file{"/run/${container}-socket":
    ensure => 'directory',
    tag => [root]
  } ->
  @lxc::container { $container:
    contname => $container,
    ip => $ips[$container],
    dir => ['/motion-socket'],
    bind => {
      "/run/${container}-socket" => { 'target' => "motion-socket"},
    },
    tag => [root]
  }
  @lxc::container_bind{ "/run/${container}-socket":
    container => 'front-nginx',
    target => "${container}-socket",
    tag => [root]
  }

  @file{"/etc/ssl/${container}-roots.pem":
    ensure => 'file',
    source => ['puppet:///modules/motion/motion-roots.pem', 'puppet:///modules/nre/config/ca/root.crt'],
    tag => [nginx]
  }
  @front_vhost{$container:
    source => 'motion/nginx.epp',
    args => {container => $container, name => $container, cert_stem => "/etc/ssl/private/${container}", domain => $domain, socket => "unix:/${container}-socket/motion.fcgi"},
    crt => "motion/${container}",
    tag => [nginx]
  }

  @file{'/etc/nginx/conf.d/bucket_size.conf':
    content => "map_hash_bucket_size 256;log_format motion-cert '\$date_gmt \$host:\$ssl_client_serial:\$ssl_client_i_dn;\$motion_user_role';\n",
    ensure => 'file',
    before => Service['nginx'],
    tag => [nginx]
  }
  @file{'/etc/nginx/conf.d/motion_map.conf':
    content => inline_epp(file('motion/user_map.epp', 'motion/user_map.template.epp'), {name => $name}),
    ensure => 'file',
    before => Service['nginx'],
    tag => [nginx]
  }


  @postgresql::server::db { $container:
    user     => $container,
    password => postgresql_password($container, 'motion'),
    tag => [primary]
  }
  @postgresql::server::pg_hba_rule { "allow ${container} to access its database":
    description => "Open up PostgreSQL for access from motion-user to its database",
    type        => 'host',
    database    => $container,
    user        => $container,
    address     => "${ips[$container]}/32",
    auth_method => 'md5',
    tag => [primary]
  }
}

define motion::frontend($domain, $container, $roots = 'puppet:///modules/motion/motion-roots.pem'){
  @file{"/etc/ssl/${name}-roots.pem":
    ensure => 'file',
    source => [$roots, 'puppet:///modules/nre/config/ca/root.crt'],
    tag => [nginx]
  }
  @front_vhost{"${container}-${domain}":
    source => 'motion/nginx.epp',
    args => {container => $container, name => $name, cert_stem => "/etc/ssl/private/${container}", domain => $domain, socket => "unix:/${container}-socket/motion.fcgi"},
    crt => "motion/${container}",
    tag => [nginx]
  }
}
