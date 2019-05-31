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
note $home;
my $COMMAND = 'Slovo::Command::Author::generate::novy_dom';
require_ok($COMMAND);
my $command = $COMMAND->new(app => $app);
isa_ok($command => 'Slovo::Command');

# Default values
my $buffer  = '';
my $db_file = $app->home->child('lib/Slovo/resources/data/slovo.development.sqlite');
subtest 'Default values' => sub {
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command->run();
  }
  like $buffer => qr/Domain.+mandatory\sargument/x => 'domains folder is mandatory';
  like $buffer => qr/Usage/x => 'help is displayed';
  ok($db_file->stat, 'database is created on the first run');
  is((unlink "$db_file"), 1, 'database removed ');

  # note $buffer;
  note '---------------------------';
};

# Custom values
$buffer = '';
subtest 'Custom values' => sub {
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command->run('-name' => 't.com');
    require Slovo::Command::Author::generate::cgi_script;
    Slovo::Command::Author::generate::cgi_script->new(app => $app)->run;
    require Slovo::Command::Author::generate::a2htaccess;
    Slovo::Command::Author::generate::a2htaccess->new(app => $app)->run;
  }
  note $buffer;
  like $buffer => qr/mkdir.+\/t\.com$/mx                => 'domain folder created';
  like $buffer => qr/mkdir.+\/t\.com\/public/x          => 'public folder created';
  like $buffer => qr/mkdir.+\/t\.com\/templates/x       => 'templates folder created';
  like $buffer => qr/write.+\/t\.com\/.+\/_form\.html/x => 'templates copied';
  like $buffer => qr/write.+\/t\.com\/.+\/fonts.css/x   => 'static files copied';
  like $buffer => qr/"site_name" => "T.COM"/            => 'new domain record';
  ok($db_file->stat->size > 1, 'database is created on the next run again');
};

done_testing;

