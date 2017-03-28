define systemd::unit_file(
  $ensure = file,
  $path = '/etc/systemd/system',
  $content = undef,
  $source = undef,
) {
  include ::systemd

  file { "${path}/${title}":
    ensure  => $ensure,
    content => $content,
    source  => $source,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['systemctl-daemon-reload'],
  }
}
