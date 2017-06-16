node postgres-primary {
  include container::contained
  include container::no_ssh

  package{ 'postgresql':
    ensure => 'installed',
    install_options => ['--no-install-recommends'],
  }

  class { 'postgresql::globals':
    version => '9.6',
  }->
  class { 'postgresql::server':
      listen_addresses => '*',
  } ->
  postgresql::server::db { 'gigi':
    require  => Package['postgresql'],
    user     => 'gigi',
    password => postgresql_password('gigi', $passwords[postgres][gigi]),
  }
  $gigi_ip = $ips[gigi];
  postgresql::server::pg_hba_rule { 'allow gigi to access its database':
    require  => Package['postgresql'],
    description => "Open up PostgreSQL for access from gigi to its database",
    type        => 'host',
    database    => 'gigi',
    user        => 'gigi',
    address     => "$gigi_ip/32",
    auth_method => 'md5',
  }

  postgresql::server::db { 'quiz':
    require  => Class['postgresql::server'],
    user     => 'quiz',
    password => postgresql_password('quiz', $passwords[postgres][quiz]),
  }
  postgresql::server::pg_hba_rule { 'allow quiz to access its database':
    require  => Package['postgresql'],
    description => "Open up PostgreSQL for access from quiz to its database",
    type        => 'host',
    database    => 'quiz',
    user        => 'quiz',
    address     => "${ips[quiz]}/32",
    auth_method => 'md5',
  }
}
