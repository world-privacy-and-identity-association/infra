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
    ensure => 'running'
  }
  file {'/certified':
    content => ''
  }
}
class container::ssh {
  package { [ 'openssh-client', 'openssh-server']:
    ensure => installed
  }
}