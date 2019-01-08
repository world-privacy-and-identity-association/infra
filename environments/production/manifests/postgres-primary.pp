node postgres-primary {
  include container::contained
  include container::no_ssh

  exec { 'backup installed':
    before => Package['postgresql'],
    notify => Exec['backup permissions corrected'],
    command => '! [ -f /var/lib/postgresql/9.6/main/PG_VERSION ] && mkdir -p /var/lib/postgresql/9.6/main && tar xzf /var/lib/postgresql/pg_base.tar.gz -C /var/lib/postgresql/9.6/main',
    onlyif => '[ -f /var/lib/postgresql/pg_base.tar.gz ]',
    provider => 'shell'
  }
  package{ 'postgresql':
    ensure => 'installed',
    install_options => ['--no-install-recommends'],
  }->
  class { 'postgresql::globals':
    version => '9.6',
  }->
  class { 'postgresql::server':
      listen_addresses => '*',
  }
  exec { 'backup permissions corrected':
    require => Class['postgresql::server::install'],
    before => Class['postgresql::server::initdb'],
    command => 'chown -R postgres:postgres /var/lib/postgresql && rm /var/lib/postgresql/pg_base.tar.gz',
    onlyif => '[ -f /var/lib/postgresql/pg_base.tar.gz ]',
    refreshonly => 'true',
    provider => 'shell'
  }
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
    require  => Exec['backup installed'],
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
  postgresql::server::pg_hba_rule{'allow local replication by postgres':
    #local   replication     postgres                ident
    type        => 'local',
    database    => 'replication',
    user        => 'postgres',
    auth_method => 'ident'
  }
  postgresql_conf{'archive_mode':
    target => '/etc/postgresql/9.6/main/postgresql.conf',
    value => 'on'
  }
  file{'/var/lib/postgresql/archive/':
    require  => Exec['backup permissions corrected'],
    ensure => 'directory',
    owner => 'postgres'
  } ->
  postgresql_conf{'archive_command':
    target => '/etc/postgresql/9.6/main/postgresql.conf',
    value => 'test ! -f /var/lib/postgresql/archive/%f && cp %p /var/lib/postgresql/archive/%f'
  }
  postgresql_conf{'wal_level':
    target => '/etc/postgresql/9.6/main/postgresql.conf',
    value => 'replica'
  }
  postgresql_conf{'max_wal_senders':
    target => '/etc/postgresql/9.6/main/postgresql.conf',
    value => '2'
  }
  Postgresql::Server::Db <| tag == primary |>
  Postgresql::Server::Pg_hba_rule <| tag == primary |>
}
