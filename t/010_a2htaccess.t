use Mojo::Base -strict;
use FindBin qw($Bin);
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
unlink $home->dirname . '/.htaccess';
my $COMMAND = 'Slovo::Command::Author::generate::a2htaccess';
require_ok($COMMAND);
my $command = $COMMAND->new(app => $app);
isa_ok($command => 'Slovo::Command');

# Default values
my $buffer = '';
{
  open my $handle, '>', \$buffer;
  local *STDOUT = $handle;
  require Slovo::Command::Author::generate::cgi_script;
  Slovo::Command::Author::generate::cgi_script->new(app => $app)->run;
  $command->run;
}
note '$home:' . $home;
note $buffer;
my $docroot = $home->dirname;
like $buffer => qr/Assuming\sDocumentRoot:\s$docroot/x        => 'default DocumentRoot';
like $buffer => qr/Assuming CGI script.+$home\/$moniker\.cgi/ => "default $moniker.cgi";
like $buffer => qr/write.+.htaccess/x                         => "creating .htaccess";
my $htaccess = $docroot->child('.htaccess');
ok -f $htaccess => "created $htaccess";

# unlink $home->dirname . '/.htaccess';
done_testing;

