use Mojo::Base -strict;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::File qw(path);

my $t = Test::Mojo->with_roles('+Slovo')->install(

# from      => to
# "$Bin/.." => '/home/berov/opt/t.com/slovo',
# 0777
)->new('Slovo');
my $app     = $t->app;
my $moniker = $app->moniker;
my $mode    = $app->mode;
my $home    = $app->home;

my $COMMAND = 'Slovo::Command::Author::inflate';
subtest 'Compiles' => sub {
  require_ok($COMMAND);
  my $command = $COMMAND->new(app => $app);
  isa_ok($command => 'Mojolicious::Command::Author::inflate');
};

chdir $home;
my $buffer = '';

#  bin/slovo inflate   # Same as `mojo inflate`!
my $default = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run();
  }

  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|,                 'no output to STDERR';
  like $buffer,   qr|templates/partials/_head|,           'inflates to $PWD/templates';
  like $buffer,   qr|public/css/malka/chota_all_min.css|, 'inflates to $PWD/public';
  like $buffer,   qr|public/css/malka/site.css|,          'inflates to $PWD/public';
  ok(path('templates')->remove_tree, 'clean inflated templates');
  ok(path('public')->remove_tree,    'clean inflated static files');
};


# bin/slovo inflate --path domove/localhost/
my $path = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(-path => path($home, 'domove/localhost')->to_string);
  }

  # no templates nor public passed, hence --path does nothing
  # note $buffer;
  like $buffer,   qr|Nothing to inflate|,       'right STDERR for --path';
  like $buffer,   qr|Inflatable|,               'lists inflatable classes';
  unlike $buffer, qr|templates/partials/_head|, 'right STDOUT for --path';
  unlike $buffer, qr|public/css|,               'right STDOUT for --path';
};

# bin/slovo inflate --class Slovo::Themes::Malka
my $class = sub {
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(-class => 'Slovo::Themes::Malka');
  }

  # no templates, nor public passed, hence --path and --class do nothing
  # note $buffer;
  like $buffer,   qr|Nothing to inflate|,       'right STDERR for --class';
  like $buffer,   qr|Inflatable|,               'lists inflatable classes';
  unlike $buffer, qr|templates/partials/_head|, 'right STDOUT for --class';
  unlike $buffer, qr|public/css|,               'right STDOUT for --class';
};

my $public = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(
      '-p'    # -class => 'Slovo::Themes::Malka'
    );
  }

  # public passed, --path and --classes are set to defaults.
  # only static files are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|,       'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,               'does not lists inflatable classes';
  unlike $buffer, qr|templates/partials/_head|, 'right STDOUT for -p';
  like $buffer,   qr|mkdir.+public/css/malka|,  '-p inflates public/css/malka';
  like $buffer,   qr|mkdir.+public/.+/openapi|, '-p inflates public/**/openapi';
  ok(path('public')->remove_tree, 'clean inflated static files');
};

my $public_and_class = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run('-p', -class => 'Slovo::Themes::Malka');
  }

  # public passed, --class passed, --path is set to default.
  # only static files are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|,       'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,               'does not list inflatable classes';
  unlike $buffer, qr|templates/partials/_head|, 'right STDOUT for -p';
  like $buffer,   qr|mkdir.+public/css/malka|,  '-p and --class inflate public/css/malka';
  unlike $buffer, qr|mkdir.+public/.+/openapi|,
    '-p, --class does not inflate public/**/openapi';
  ok(path('public')->remove_tree, 'clean inflated static files');
};

my $public_templates_and_class = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run('-p', '-t', -class => 'Slovo::Themes::Malka');
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|templates/partials/_head|,
    '-p, -t and --class inflate all for this class';
  like $buffer, qr|mkdir.+public/css/malka|,
    '-p, -t and --class inflate public/css/malka';
  unlike $buffer, qr|mkdir.+public/.+/openapi|,
    '-p, -t and --class does not inflate public/**/openapi';
  ok(path('public')->remove_tree,    'clean inflated static files');
  ok(path('templates')->remove_tree, 'clean inflated templates');

  # Multiple classes
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)
      ->run('-p', '-t',
      -class => 'Slovo::Themes::Malka,' . 'Mojolicious::Plugin::PODViewer');
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|templates/partials/_head|,
    '-p, -t and --class inflate all for these classes';
  like $buffer, qr|mkdir.+templates/layouts|,
    '-p, -t and --class inflate all for these classes';
  like $buffer, qr|mkdir.+public/css/malka|,
    '-p, -t and --class inflate public/css/malka';
  unlike $buffer, qr|mkdir.+public/.+/openapi|,
    '-p, -t and --class does not inflate public/**/openapi';
  ok(path('public')->remove_tree,    'clean inflated static files');
  ok(path('templates')->remove_tree, 'clean inflated templates');

};


my $public_templates_path_and_class = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)
      ->run('-p', '-t', -path => 'domove/localhost', -class => 'Slovo::Themes::Malka');
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|localhost/templates/partials/_head|,
    '-p, -t, --path and --class inflate all for this class';
  like $buffer, qr|mkdir.+host/public/css/malka|,
    '-p, -t, --path and --class inflate public/css/malka';
  unlike $buffer, qr|mkdir.+host/public/.+/openapi|,
    '-p, -t, --path and --class does not inflate public/**/openapi';

  #Multiple classes
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(
      '-p', '-t',
      -path  => 'domove/localhost',
      -class => 'Slovo::Themes::Malka,' . 'Mojolicious::Plugin::PODViewer'
    );
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|host/templates/partials/_head|,
    '-p, -t, --path and --class inflate all for these classes';
  like $buffer, qr|mkdir.+host/templates/podviewer|,
    '-p, -t, --path and --class inflate all for these classes';
  like $buffer, qr|exist.+host/public/css/malka|,
    '-p, -t, --path and --class inflate public/css/malka';
  unlike $buffer, qr|mkdir.+host/public/.+/openapi|,
    '-p, -t and --class does not inflate public/**/openapi';
};

subtest Default => $default;
subtest Path    => $path;
subtest Class   => $class;
subtest Public  => $public;

subtest Public_and_Class                => $public_and_class;
subtest Public_Templates_and_Class      => $public_templates_and_class;
subtest Public_Templates_Path_and_Class => $public_templates_path_and_class;

chdir path($Bin)->dirname;

done_testing;
