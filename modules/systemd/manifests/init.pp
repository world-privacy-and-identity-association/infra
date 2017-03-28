class systemd (){
  exec {'systemctl-daemon-reload':
    command => '/bin/systemctl daemon-reload',
    refreshonly => true
  }
}