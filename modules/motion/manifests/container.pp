class motion::container($container){
  include container::contained;
  include container::no_ssh;

  package{ ['python3', 'python3-pip',  'virtualenv', 'libpq-dev']:
    ensure => 'installed'
  }
  user{'motion':
    ensure => present,
    home => '/home/motion',
    system => 'yes'
  } ->
  file{'/home/motion':
    ensure => 'directory',
    owner => 'motion',
    group => 'motion'
  }
  file{'/motion-socket':
    owner => 'motion',
    group => 'motion'
  }
  package{'git':
  } ->
  exec{'clone motion':
    command => '/usr/bin/git clone https://code.wpia.club/motion.git',
    cwd => '/home/motion',
    creates => '/home/motion/motion/.git',
    user => 'motion'
  } ->
  file{'/home/motion/motion/__pycache__':
    ensure => directory,
    owner => motion,
    group => motion
  } ->
  file{'/home/motion/motion/config.py':
    content => epp("motion/config.py", {user => $container, password => 'motion'}),
    owner => motion,
    group => motion
  } ->
  exec {'motion-virtualenv':
    command => '/usr/bin/virtualenv -p python3 motion',
    cwd => '/home/motion',
    creates => '/home/motion/motion/bin/activate',
    user => 'motion',
    require => [Package['virtualenv'], Package['python3-pip'], Exec['clone motion']],
    before =>  Service['motion.service'],
  } ->
  exec{'pip dependencies':
    command => '/bin/bash -c "source motion/bin/activate; /home/motion/motion/bin/pip install -r motion/requirements.txt"',
    require => [Exec['motion-virtualenv'],Package['python3-pip']],
    cwd => '/home/motion',
    timeout => 0,
    user => 'motion',
    creates => '/home/motion/motion/bin/flask'
  }

  exec{'install uwsgi':
    command => '/bin/bash -c "source motion/bin/activate; /home/motion/motion/bin/pip install uwsgi"',
    require => Exec['motion-virtualenv'],
    cwd => '/home/motion',
    timeout => 0,
    user => 'motion',
    creates => '/home/motion/motion/bin/uwsgi'
  }

  file{'/home/motion/motion.ini':
    source => 'puppet:///modules/motion/motion.ini'
  } ->
  systemd::unit_file {'motion.service':
    ensure => 'file',
    source => 'puppet:///modules/motion/motion.service',
    notify => Service['motion.service'],
    require => Exec['install uwsgi']
  }
  service{'motion.service':
    ensure => 'running',
    provider => 'systemd',
    enable => true,
    require => [Exec['pip dependencies'],Exec['systemctl-daemon-reload']],
  }

}
