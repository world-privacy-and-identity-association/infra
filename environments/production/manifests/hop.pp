node hop{
  include container::contained

  package { 'tmux':
    ensure => 'installed';
  }
  package { 'emacs-nox':
    ensure => 'installed';
  }
  user { 'admin':
    ensure => 'present',
    shell => '/bin/bash'
  }
  file { '/home/admin':
    require => User['admin'],
    ensure => 'directory',
    owner => 'admin'
  }
  file { '/home/admin/join':
    ensure => 'present',
    source => 'puppet:///modules/hop/join',
    mode => 'a+x',
    owner => 'root'
  }
  file { '/home/admin/commands':
    ensure => 'present',
    content => epp('hop/commands'),
    mode => 'a+x',
    owner => 'root'
  }
   file { '/home/admin/.ssh':
    ensure => 'directory',
    owner => 'admin'
  }
  file { '/home/admin/.ssh/authorized_keys':
    ensure => 'present',
    source => 'puppet:///modules/hop/authorized_keys',
    owner => 'root'
  }
}
