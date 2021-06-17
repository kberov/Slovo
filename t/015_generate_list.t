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
my $COMMAND = 'Slovo::Command::Author::generate';
require_ok($COMMAND);
my $command    = $COMMAND->new(app => $app);
my $GENERATORS = 'Mojolicious::Command::Author::generate';
isa_ok($command => $GENERATORS);

ok $command->description,       'has a description';
like $command->message,         qr/generate/, 'has a message';
like $command->hint,            qr/help/,     'has a hint';
is_deeply $command->namespaces, [$COMMAND, $GENERATORS], 'right namespaces';
my $buffer = '';
{
  open my $handle, '>', \$buffer;
  local *STDOUT = $handle;
  local $ENV{HARNESS_ACTIVE} = 0;
  $command->run();
}
for (qw(app dockerfile lite-app makefile plugin)) {
  like $buffer => qr|$_| => "$GENERATORS\:\:$_ is listed";
}
for (qw(cgi-script a2htaccess novy-dom)) {
  like $buffer => qr|$_| => "$COMMAND\:\:$_ is listed";
}

done_testing;

