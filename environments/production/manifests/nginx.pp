define front_vhost($source, $crt = undefined, $args = {}){
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
    content => epp($source, $args),
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
  apt_key{ 'E643C483A426BB5311D26520A631B6AF9FD3DF94':
    source => 'http://deb2.dogcraft.de/signer.gpg',
    ensure => 'present'
  } ->
    file { '/etc/apt/sources.list.d/dogcraft.list':
      source => 'puppet:///modules/lxc/dogcraft.list',
      ensure => 'present',
      notify => Exec['apt_update']
  }
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
  package{'wpia-infradocs':
    ensure => 'installed'
  } ->
  front_vhost{'infradocs':
    source => 'infradocs/nginx',
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
    ensure => 'running',
    enable => true,
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

  Front_vhost <| tag == nginx |> ~> Service['nginx']
  File <| tag == nginx |> ~> Service['nginx']
}
