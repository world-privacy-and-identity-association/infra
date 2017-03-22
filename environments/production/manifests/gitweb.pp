node gitweb {
  include container::contained;
  include container::no_ssh;
  package{ 'git':
    ensure => 'installed'
  }
  package{ 'libcgi-fast-perl':
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
  file{ '/etc/systemd/system/git.socket':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/git.socket',
    before => Service['git.socket']
  }
  file{ '/etc/systemd/system/git@.service':
    ensure => 'file',
    source => 'puppet:///modules/gitweb/git@.service',
    before => Service['git.socket']
  }
  service{'git.socket':
    ensure => 'running',
    provider => 'systemd',
    enable => true
  }
  file{ '/etc/systemd/system/gitweb.service':
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
}