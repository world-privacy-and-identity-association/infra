define teracara_quiz (){
  apt_key{ 'E643C483A426BB5311D26520A631B6AF9FD3DF94':
    source => 'http://deb.dogcraft.de/signer.gpg',
    ensure => 'present'
  } ->
  file { '/etc/apt/sources.list.d/dogcraft.list':
    source => 'puppet:///modules/lxc/dogcraft.list',
    ensure => 'present',
    notify => Exec['apt_update']
  }
  package { 'teracara-quiz':
    require => Exec['apt_update'],
    ensure => 'installed',
  }
  package { 'apache2':
    ensure => 'installed',
  }
  file {'/etc/teracara-quiz/config.php':
      require => Package['teracara-quiz'],
      ensure => 'file',
      content => epp('quiz/config.php'),
  }
  file {'/etc/teracara-quiz/client.crt':
      require => Package['teracara-quiz'],
      ensure => 'file',
      show_diff => 'false',
      source => 'puppet:///modules/quiz/client.crt',
  }
  file {'/etc/teracara-quiz/client.key':
      require => Package['teracara-quiz'],
      ensure => 'file',
      show_diff => 'false',
      source => 'puppet:///modules/quiz/client.key',
  }
  file {'/etc/teracara-quiz/sq_config.php':
      require => Package['teracara-quiz'],
      ensure => 'file',
      content => epp('quiz/sq_config'),
  }
  file{'/etc/teracara-quiz/root.crt':
      require => Package['teracara-quiz'],
      ensure => 'file',
      source => ['puppet:///modules/nre/config/ca/root.crt'],
      show_diff => 'no'
  }
  include postgresql::client
  exec { 'import quiz schema':
    command => "/usr/bin/psql -U quiz -h ${ips[postgres]} < /usr/share/teracara-quiz/sql/db_postgresql.sql",
    environment => ["PGPASSWORD=${passwords[postgres][quiz]}"],
    unless  => "/usr/bin/psql -U quiz -h ${ips[postgres]} -tc \"select * from pg_tables where schemaname='public';\" | /bin/grep -q '.'",
    require => [Package['teracara-quiz'], Class['postgresql::client']],
    before => File['/etc/apache2/sites-available/000-default.conf']
  }
  file {'/etc/apache2/sites-available/000-default.conf':
      require => Package['apache2'],
      ensure => 'file',
      source => 'puppet:///modules/quiz/000-default.conf',
      notify => Service['apache2'],
  }
  package{'mariadb-server':
      ensure => 'purged'
  }
  package{'mariadb-client':
      ensure => 'purged'
  }
}
node quiz{
  include container::contained;
  include container::no_ssh;

  teracara_quiz{ 'quiz': }
  service {'apache2':
      require => Teracara_quiz['quiz'],
      ensure => 'running',
  }

}

