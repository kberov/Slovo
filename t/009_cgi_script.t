use Mojo::Base -strict;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::File qw(path);
use Mojo::Util qw(decode);
my $t = Test::Mojo->with_roles('+Slovo')->install(

# from => to
# "$Bin/.." => '/home/berov/opt/t.com/slovo',
# 0777
)->new('Slovo');
my $app     = $t->app;
my $moniker = $app->moniker;
my $mode    = $app->mode;
my $home    = $app->home;
my $COMMAND = 'Slovo::Command::Author::generate::cgi_script';
require_ok($COMMAND);
my $command = $COMMAND->new(app => $app);
isa_ok($command => 'Slovo::Command');

# Default values
my $buffer = '';
{
  open my $handle, '>', \$buffer;
  local *STDOUT = $handle;
  $command->run;
}
like $buffer => qr/Assuming\sscript\sname:\s$moniker\.cgi/x => 'default cgi script name';
like $buffer => qr/Assuming\smode:\s$mode/x                 => 'default mode';
like $buffer => qr/write.+$home\/$moniker\.cgi/x            => "creating $moniker.cgi";
my $cgi = path "$home/$moniker.cgi";
ok -f $cgi => "created $cgi";
my $exe = $command->exe;
note '$exe: ', $exe;
ok((-f $exe) => 'exe exists');
my $cgi_content = $cgi->slurp;
like $cgi_content => qr/\s'$mode';/ => "cgi sets current mode as default";
like $cgi_content => qr/\s'$home';/ => "cgi sets current home as default";

# Passed values
$buffer = '';
{

  $mode = 'production';
  Slovo->new(mode => $mode)->dbx->migrations->migrate;
  open my $handle, '>', \$buffer;
  local *STDOUT = $handle;
  $command->run('-c' => $mode, '--filename' => 'index.cgi');
}

unlike $buffer => qr/Assuming/x => 'passed cgi script name as argument';
unlike $buffer => qr/Assuming/x => 'passed mode as argument';
$cgi = path "$home/index.cgi";
like $buffer => qr/write.+$cgi/x => "creating cgi";
ok(-f $cgi => "created $cgi");
$exe = $command->exe;
note $exe;
ok(-f $exe => 'exe exists');
$cgi_content = $cgi->slurp;
like $cgi_content => qr/\s'$mode';/ => "cgi sets passed mode as default";
like $cgi_content => qr/\s'$home';/ => "cgi sets current home as default";

#cgi executes properly
{
  local $ENV{MOJO_MODE};
  local $ENV{MOJO_HOME};
  my $out = qx/$cgi cgi 2>&1/;
  like decode('UTF-8' => $out) => qr/Добре дошли/ => "cgi output"
}

done_testing;

