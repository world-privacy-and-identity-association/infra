class lxc {
    file {"/data/log":
        ensure => 'directory'
    }
    package{ 'lxc':
        ensure => 'installed'
    }->
    exec {'lxc-base-image-created':
        logoutput => on_failure,
        command => '/usr/bin/lxc-create -n base-image -t debian -- -r stretch --packages=gnupg2,puppet,lsb-release,debconf-utils && rm -r /var/lib/lxc/base-image/rootfs/var/lib/apt/lists',# gnupg2 needed for puppet managing apt-keys
        unless => '/usr/bin/test -d /var/lib/lxc/base-image',
        timeout => '0'
    }
    define container ($contname, $ip, $dir = [], $bind = {}, $confline = []) {
        exec {"lxc-$contname-issue-cert":
          command => "/usr/bin/puppet ca destroy \"$contname\";/usr/bin/puppet ca generate \"$contname\"",
          unless => "/usr/bin/[ -f /var/lib/puppet/ssl/private_keys/$contname.pem ] && /usr/bin/[ -f /var/lib/puppet/ssl/certs/$contname.pem ]",
          before => Exec["lxc-$contname-started"]
        }

        exec{ "lxc-$contname-created":
            logoutput => on_failure,
            command   => "/usr/bin/lxc-copy -n base-image -N $contname",
            unless    => "/usr/bin/test -d /var/lib/lxc/$contname",
            timeout   => '0',
            require   => [Package['lxc'],Exec['lxc-base-image-created']],
        } -> file_line {"lxc-$contname-conf1":
            path   => "/var/lib/lxc/$contname/config",
            line   => 'lxc.network.type = veth',
            notify => Exec["lxc-$contname-started"],
        } -> file_line {"lxc-$contname-conf2":
            path   => "/var/lib/lxc/$contname/config",
            line   => 'lxc.network.link = lxcbr0',
            notify => Exec["lxc-$contname-started"],
        } -> file_line {"lxc-$contname-conf3":
            path   => "/var/lib/lxc/$contname/config",
            line   => 'lxc.network.flags = up',
            notify => Exec["lxc-$contname-started"],
        } -> file_line {"lxc-$contname-conf4":
            path   => "/var/lib/lxc/$contname/config",
            line   => "lxc.network.ipv4 = $ip/24",
            notify => Exec["lxc-$contname-started"],
        } -> file_line {"lxc-$contname-conf5":
            path   => "/var/lib/lxc/$contname/config",
            line   => 'lxc.network.ipv4.gateway = 10.0.3.1',
            notify => Exec["lxc-$contname-started"],
        } -> file_line {"lxc-$contname-network":
            path   => "/var/lib/lxc/$contname/rootfs/etc/network/interfaces",
            line   => 'iface eth0 inet manual',
            match  => '^iface eth0 inet',
            notify => Exec["lxc-$contname-started"],
        } -> exec {"lxc-$contname-started":
            path => '/usr/bin',
            refreshonly   => true,
            refresh   => "/usr/bin/lxc-stop -n $contname ; /usr/bin/lxc-start -dn $contname",
        }-> exec {"lxc-$contname-started1":
            command   => "/usr/bin/lxc-start -dn $contname",
            unless    => "/usr/bin/[ \"\$(lxc-info -Hsn $contname)\" != \"STOPPED\" ]",
        }
        $dir.each |String $in| {
          file { "/var/lib/lxc/$contname/rootfs/$in":
            ensure  => 'directory',
            notify => Exec["lxc-$contname-started"],
            require => File_line["lxc-$contname-conf5"]
          }
        }
        $bind.each |String $out, Struct[{target=>String, Optional[option]=>String}] $in| {
          file_line { "lxc-$contname-mount-$out":
           path   => "/var/lib/lxc/$contname/config",
           line   => "lxc.mount.entry = $out ${in[target]} none bind${in[option]} 0 0",
           require=> [File_line["lxc-$contname-conf5"], File["$out"]],
           notify  => Exec["lxc-$contname-started"],
          }
        }
        file {"/data/log/$contname":
           ensure => 'directory'
        }->
        file_line { "lxc-$contname-mount-journal":
           path   => "/var/lib/lxc/$contname/config",
           line   => "lxc.mount.entry = /data/log/$contname var/log/journal none bind 0 0",
           require=> File_line["lxc-$contname-conf5"],
           notify  => Exec["lxc-$contname-started"],
        }
        file {"/var/lib/lxc/$contname/rootfs/var/log/journal":
            ensure  => 'directory',
            notify => Exec["lxc-$contname-started"],
            require => File_line["lxc-$contname-conf5"]
        }
        $confline.each |Integer $idx, String $in| {
         file_line { "lxc-$contname-confline-extra-$idx":
           path   => "/var/lib/lxc/$contname/config",
           line   => "$in",
           require=> File_line["lxc-$contname-conf5"],
           notify  => Exec["lxc-$contname-started"],
         }
        }
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet":
             ensure => 'directory',
             require => Exec["lxc-$contname-created"]
        }
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet/ssl":
             ensure => 'directory'
        }
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet/ssl/private_keys/":
             ensure => 'directory'
        }
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet/ssl/certs/":
             ensure => 'directory'
        }
        Exec["lxc-$contname-started1"] ->
        file_line {"lxc-$contname-hosts":
            path   => "/var/lib/lxc/$contname/rootfs/etc/hosts",
            line   => '10.0.3.1 puppet puppet.lan host01';
        }->
        file_line {"lxc-$contname-hosts-local":
            path   => "/var/lib/lxc/$contname/rootfs/etc/hosts",
            line   => "127.0.0.1 $contname"
        }->
        file_line {"lxc-$contname-resolv1":
            path   => "/var/lib/lxc/$contname/rootfs/etc/resolv.conf",
            ensure => 'absent',
            match_for_absence => "true",
            match  => '^domain ',
            line   => ''
        }->
        file_line {"lxc-$contname-resolv2":
            path   => "/var/lib/lxc/$contname/rootfs/etc/resolv.conf",
            ensure => 'absent',
            match_for_absence => "true",
            match  => '^search ',
            line   => ''
        } ->
        exec {"lxc-$contname-install-puppet":
          command => "/usr/bin/lxc-attach -n \"$contname\" -- apt-get update && /usr/bin/lxc-attach -n \"$contname\" -- apt-get install -y puppet",
          timeout => '0',
          creates => "/var/lib/lxc/$contname/rootfs/usr/bin/puppet"
        } ->
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet/ssl/private_keys/$contname.pem":
          source => "file:///var/lib/puppet/ssl/private_keys/$contname.pem",
          notify => Exec["lxc-$contname-puppet-restart"],
        } ->
        file {"/var/lib/lxc/$contname/rootfs/var/lib/puppet/ssl/certs/$contname.pem":
          source => "file:///var/lib/puppet/ssl/certs/$contname.pem",
          notify => Exec["lxc-$contname-puppet-restart"],
        }
        exec {"lxc-$contname-puppet-restart":
          command => "/usr/bin/lxc-attach -n $contname -- systemctl stop puppet",
          timeout   => '0',
          refreshonly => 'true'
        } ~>
        exec {"lxc-$contname-refresh":
          command => "/usr/bin/lxc-attach -n $contname -- puppet agent --onetime --no-daemonize --verbose",
          timeout   => '0',
          # TODO figure out a way to verify puppet launches
          creates => "/var/lib/lxc/$contname/rootfs/certified"
          ##creates => "/var/lib/lxc/$contname/rootfs/lib/systemd/system/puppet.service"
        } ~>
        exec {"lxc-$contname-puppet-start":
          command => "/usr/bin/lxc-attach -n $contname -- systemctl start puppet",
          timeout   => '0',
          refreshonly => 'true'
        }
    }

}
