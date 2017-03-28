node gitweb {
  include container::contained;
  include container::no_ssh;
  package{ 'git':
    ensure => 'installed'
  }
  package{ 'libcgi-fast-perl':
    ensure => 'installed'
  }
  package{ 'fcgiwrap':
    ensure => 'installed'
  }
  user{'git':
    ensure => 'present',
    system => 'yes',
    comment => 'git repository owner'
  } ->
  file{ '/gitweb-socket':
    owner => 'git',
    group => 'git',
    before => Service['gitweb.service']
  }
  systemd::unit_file {'git.socket':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/git.socket',
    before => Service['git.socket']
  }
  systemd::unit_file {'git@.service':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/git@.service',
    before => Service['git.socket']
  }
  service{'git.socket':
    ensure => 'running',
    provider => 'systemd',
    enable => true
  }
  systemd::unit_file {'gitweb.service':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/gitweb.service',
    notify => Service['gitweb.service']
  }
  file{ '/usr/local/bin/gitweb.cgi':
    ensure => 'file',
    mode => '+x',
    source => 'puppet:///modules/gitweb/gitweb-wrapper.cgi',
    notify => Service['gitweb.service']
  }
  file{ '/etc/gitweb.conf':
    ensure => 'file',
    content => epp('gitweb/gitweb.conf'),
    notify => Service['gitweb.service']
  }
  service{'gitweb.service':
    ensure => 'running',
    provider => 'systemd',
    enable => true
  }
  file{ '/etc/systemd/system/fcgiwrap.socket.d':
    ensure => 'directory'
  }
  systemd::unit_file {'fcgiwrap.socket.d/ListenStream.conf':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/fcgiwrap-ListenStream.conf',
    notify => Service['fcgiwrap.socket']
  }
  file{ '/etc/systemd/system/fcgiwrap.service.d':
    ensure => 'directory'
  }
  systemd::unit_file {'fcgiwrap.service.d/sandbox.conf':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/fcgiwrap-sandbox.conf',
    notify => Service['fcgiwrap.socket']
  }
  file{ '/etc/default/fcgiwrap':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/fcgiwrap-default',
    notify => Service['fcgiwrap.socket']
  }
  service{'fcgiwrap.socket':
    ensure => 'running',
    provider => 'systemd',
    enable => true
  }
}
