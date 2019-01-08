$ips = {
   front-nginx => '10.0.3.13',
   gigi => '10.0.3.15',
   cassiopeia => '10.0.3.16',
   exim => '10.0.3.17',
   hop => '10.0.3.18',
   quiz => '10.0.3.19',
   postgres => '10.0.3.14',
   motion => '10.0.3.22',
   gitweb => '10.0.3.20'}

$ipsv6 = {
   front-nginx => 'fc00:1::d',
   postgres => 'fc00:1::e',
   postgres-primary => 'fc00:1::e',
   gigi => 'fc00:1::f',
   cassiopeia => 'fc00:1::10',
   exim => 'fc00:1::11',
   hop => 'fc00:1::12',
   quiz => 'fc00:1::13',
   motion => 'fc00:1::16',
   gitweb => 'fc00:1::14'}

$passwords = {
   postgres => {
     gigi => 'gigi',
     quiz => 'quiz'
   },
}

$testServer = 'false'

$internet_iface = 'unknown'
$systemDomain = 'unknown'
$gigi_translation = 'unknown'
$signerLocation = 'self'
$protected='no'
$administrativeUser = 'admin'
