use open qw(:std :utf8);
use Mojo::Base -strict;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::File qw(path);
use Mojo::Util qw(decode);
my $t = Test::Mojo->with_roles('+Slovo')->install(

# from      => to
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
my $db_file = $app->resources->child("data/$moniker.$mode.sqlite");
subtest 'Default values' => sub {
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command->run();
  }
  like $buffer => qr/Domain.+mandatory\sargument/x => 'domains folder is mandatory';
  like $buffer => qr/Usage/x                       => 'help is displayed';
  ok($db_file->stat, 'database is created on the first run');

  # note $buffer;
  note '---------------------------';
};

# Custom values
subtest 'Domain name' => sub {

  $buffer = '';
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command->run('-name' => 't.com');
    require Slovo::Command::Author::generate::cgi_script;
    Slovo::Command::Author::generate::cgi_script->new(app => $app)->run;
    require Slovo::Command::Author::generate::a2htaccess;
    Slovo::Command::Author::generate::a2htaccess->new(app => $app)->run;
    close $handle;
  }

  # note $buffer;
  like $buffer => qr/mkdir.+\/t\.com$/mx                => 'domain folder created';
  like $buffer => qr/mkdir.+\/t\.com\/public/x          => 'public folder created';
  like $buffer => qr/mkdir.+\/t\.com\/templates/x       => 'templates folder created';
  like $buffer => qr/write.+\/t\.com\/.+\/_form\.html/x => 'templates copied';
  like $buffer => qr/write.+\/t\.com\/.+\/fonts.css/x   => 'static files copied';
  like $buffer => qr/"site_name" => "t.com"/            => 'new domain record';
  like $buffer => qr/Assuming\sdomain\sal.+dev.t.com/x  => 'default domain prefixes';
};

# Domain Aliases
subtest 'Custom aliases' => sub {
  $buffer = '';
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command->run(
      '--name'    => 't1.com',
      '--aliases' => 't2.com,t3.com',
      '--skip'    => '\.css$'
    );
    require Slovo::Command::Author::generate::cgi_script;
    Slovo::Command::Author::generate::cgi_script->new(app => $app)->run;
    require Slovo::Command::Author::generate::a2htaccess;
    Slovo::Command::Author::generate::a2htaccess->new(app => $app)->run;
  }

  like $buffer   => qr/(?:mkdir|exist).+\/t1\.com$/mx     => 'domain folder created';
  like $buffer   => qr/Domain\salia.+t2.com.+dev.t1.com/x => 'custom aliases';
  unlike $buffer => qr/\.css$/ms                          => 'skip ' . $command->skip_qr;
};

subtest 'Skip and refresh files' => sub {

  $buffer = '';
  my $command;
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $command = $app->commands->run(
      generate    => 'novy_dom',
      '--name'    => 't.com',
      '--skip'    => '\.css$',
      '--refresh' => 'partials/.+\.ep$'
    );
  }
  like $buffer => qr/unlink.+_beleyazhka\.html\.ep/ => 'unlink ' . $command->refresh_qr;
  like $buffer => qr/\[write\].+_beleyazhka\.html\.ep/ => 'refresh '
    . $command->refresh_qr;
  unlike $buffer => qr/\.css$/ms => 'skip ' . $command->skip_qr;

  # note $buffer;
  # note '---------------------------';
};
done_testing;

