define front_vhost($source, $crt = undefined){
  if $crt {
    file{"/etc/ssl/private/$name.crt":
      ensure => 'file',
      source => ["puppet:///modules/$crt.crt", 'puppet:///modules/gigi/gigi.crt'],
      show_diff => 'no',
      notify => Service['nginx'],
      before => File["/etc/nginx/sites-available/$name.conf"]
    }
    file{"/etc/ssl/private/$name.key":
      ensure => 'file',
      source => ["puppet:///modules/$crt.key", 'puppet:///modules/gigi/gigi.key'],
      show_diff => 'no',
      before => File["/etc/nginx/sites-available/$name.conf"]
    }
  }
  file {"/etc/nginx/sites-available/$name.conf":
    ensure => 'file',
    content => epp($source),
    require => Package['nginx-light'],
  }->
  file {"/etc/nginx/sites-enabled/$name.conf":
    ensure => 'link',
    target => "/etc/nginx/sites-available/$name.conf",
    require => Package['nginx-light'],
    notify => Service['nginx']
  }
}

node front-nginx {
  include container::contained;
  include container::no_ssh;
  package{ 'nginx-light':
    ensure => 'installed'
  }
  $gigi_ip = $ips[gigi];
  front_vhost{'gigi':
    source => 'gigi/nginx',
    crt => 'gigi/gigi',
    notify => Service['nginx']
  }
  front_vhost{'crl':
    source => 'crl/nginx',
    notify => Service['nginx']
  }
  if($protected != 'no') {
    file{'/etc/nginx/access.txt':
      content => $protected,
      require => Package['nginx-light'],
      before => Service['nginx']
    }
  }
  file{'/etc/ssl/root.crt':
    ensure => 'file',
    source => ['puppet:///modules/nre/config/ca/root.crt'],
    show_diff => 'no',
    notify => Service['nginx'],
    before => Front_vhost['quiz']
  }
  front_vhost{'quiz':
    source => 'quiz/nginx',
    crt => 'quiz/web',
    notify => Service['nginx']
  }
  service {'nginx':
    ensure => 'running'
  }
  #for gitweb hosting
  package{'git':
    ensure=>'installed'
  }
  front_vhost{'gitweb':
    source => 'gitweb/nginx.epp',
    notify => Service['nginx'],
    crt => 'gitweb/web'
  }
}
