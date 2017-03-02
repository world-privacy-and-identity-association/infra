$ips = {
   front-nginx => '10.0.3.13',
   gigi => '10.0.3.15',
   cassiopeia => '10.0.3.16',
   exim => '10.0.3.17',
   hop => '10.0.3.18',
   quiz => '10.0.3.19',
   postgres => '10.0.3.14'}

$passwords = {
   postgres => {
     gigi => 'gigi'
   },
   quiz-mysql => {
     root => 'root',
     quiz => 'quiz'
   }
}

$testServer = 'false'

$internet_iface = 'unknown'
$systemDomain = 'unknown'
$gigi_translation = 'unknown'
$signerLocation = 'self'
$protected='no'
$administrativeUser = 'admin'
