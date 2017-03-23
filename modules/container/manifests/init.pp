class container::no_ssh {
  package { [ 'openssh-client', 'openssh-server']:
    ensure => purged
  }
}
class container::contained {
  package { 'puppet':
    ensure => installed
  }
  service { 'puppet':
    ensure => 'running',
    enable => true,
  }
  file {'/certified':
    content => ''
  }
  service {'getty@tty1':
    ensure => 'stopped',
    enable => 'mask'
  }
  service {'getty@tty2':
    ensure => 'stopped',
    enable => 'mask'
  }
  service {'getty@tty3':
    ensure => 'stopped',
    enable => 'mask'
  }
  service {'getty@tty4':
    ensure => 'stopped',
    enable => 'mask'
  }
  service {'console-getty':
    ensure => 'stopped',
    enable => 'mask'
  }
}
class container::ssh {
  package { [ 'openssh-client', 'openssh-server']:
    ensure => installed
  }
}