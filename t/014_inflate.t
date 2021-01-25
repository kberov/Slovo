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
  unlike $buffer, qr|Nothing to inflate|,             'no output to STDERR';
  like $buffer,   qr|$home/templates/partials/_head|, 'inflates to $PWD/templates';
  like $buffer,   qr|$home/public/css/malka/chota_all_min.css|, 'inflates to $PWD/public';
  like $buffer,   qr|$home/public/css/malka/site.css|,          'inflates to $PWD/public';
  ok(path('templates')->remove_tree, 'clean inflated templates');
  ok(path('public')->remove_tree,    'clean inflated static files');
};


# bin/slovo inflate --path domove/localhost/
my $path = sub {
  my $path = path($home, 'domove/localhost')->to_string;
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(-path => $path);
  }

  # no -p nor -t passed, hence --path does nothing by it self
  # note $buffer;
  like $buffer,   qr|Nothing to inflate|, 'right STDERR for --path';
  like $buffer,   qr|Inflatable|,         'lists inflatable classes';
  unlike $buffer, qr|partials/_head|,     'right STDOUT for --path';
  unlike $buffer, qr|css|,                'right STDOUT for --path';
};

# bin/slovo inflate --class Slovo::Themes::Malka
my $class = sub {
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(-class => 'Slovo::Themes::Malka');
  }

  # no templates, nor public passed, --class does nothing by it self
  # note $buffer;
  like $buffer,   qr|Nothing to inflate|, 'right STDERR for --class';
  like $buffer,   qr|Inflatable|,         'lists inflatable classes';
  unlike $buffer, qr|partials/_head|,     'right STDOUT for --class';
  unlike $buffer, qr|css|,                'right STDOUT for --class';
};

my $public = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run('-p');
  }

  # public passed, --path and --classes are set to defaults.
  # only static files from all classes are inflated to $home/pubic.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|,             'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,                     'does not lists inflatable classes';
  unlike $buffer, qr|$home/templates/partials/_head|, 'right STDOUT for -p';
  like $buffer,   qr|mkdir.+$home/public/css/malka|,
    '-p inflates to $home/public/css/malka';
  like $buffer, qr|mkdir.+$home/public/.+/openapi|,
    '-p inflates to $home/public/**/openapi';
  ok(path('public')->remove_tree, 'clean inflated static files');
};

my $public_and_class = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run('-p', -class => 'Slovo::Themes::Malka');
  }

  # public passed, --class passed, --path is set to default($home).
  # only static files are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|,             'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,                     'does not list inflatable classes';
  unlike $buffer, qr|$home/templates/partials/_head|, 'right STDOUT for -p';
  like $buffer,   qr|mkdir.+$home/public/css/malka|,
    '-p and --class inflate to $home/public/css/malka';
  unlike $buffer, qr|mkdir.+$home/public/.+/openapi|,
    '-p and --class do not inflate to $home/public/**/openapi';
  ok(path('public')->remove_tree, 'clean inflated static files');
};

my $public_templates_and_class = sub {

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run('-p', '-t', -class => 'Slovo::Themes::Malka');
  }

  # -p passed, -t passed, --class passed, --path is set to default($home).
  # static files and templates are inflated and prefixed.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|$home/templates/partials/_head|,
    '-t and --class inflate to $home/ for this class';
  like $buffer, qr|mkdir.+$home/public/css/malka|,
    '-p and --class inflate to $home/css/malka';
  unlike $buffer, qr|mkdir.+$home/public/.+openapi|,
    '-p, -t and --class does not inflate to $home/**/openapi';
  ok(path($home, 'public')->remove_tree,    'clean inflated static css files');
  ok(path($home, 'templates')->remove_tree, 'clean inflated templates');

  my $params = [
    '-p', '-t',
    -class => 'Slovo::Themes::Malka,' . 'Mojolicious::Plugin::OpenAPI::SpecRenderer'
  ];

  # Multiple classes
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(@$params);
  }

  # -p passed, -t passed, --class passed, --path is set to default($home).
  # static files and templates are prefixed and inflated.
  # note $buffer;
  note '$COMMAND->new(app => $app)->run(@$params);' . $/ . ' $params = ', explain $params;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|$home/templates/partials/_head|,
    '-p, -t and --class inflate all for these classes';
  like $buffer, qr|mkdir.+$home/templates/layouts|,
    '-p, -t and --class inflate all for these classes';
  like $buffer, qr|mkdir.+$home/public/css/malka|,
    '-p, -t and --class inflate $home/public/css/malka';
  like $buffer, qr|mkdir.+$home/public/.+/openapi|,
    '-p, -t and --class do inflate to public/**/openapi';
  ok(path('public')->remove_tree,    'clean inflated static files');
  ok(path('templates')->remove_tree, 'clean inflated templates');

};


my $public_templates_path_and_class = sub {
  my $params
    = ['-p', '-t', -path => 'domove/localhost/x', -class => 'Slovo::Themes::Malka'];

  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(@$params);
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  note '$params = ', explain $params;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|$params->[3]/partials/_head|,
    '-p, -t, --path and --class inflate all templates for this class to --path';
  like $buffer, qr|mkdir.+$params->[3]/css/malka|,
    '-p, -t, --path and --class inflate all static files to --path';
  unlike $buffer, qr|mkdir.+$params->[3]/.+/openapi|,
    '-p, -t, --path and --class does not inflate to --path/**/openapi';
  ok(path($params->[3])->remove_tree, 'clean inflated files');

  #Multiple classes
  $params = [
    '-p', '-t',
    -path  => $params->[3],
    -class => 'Slovo::Themes::Malka,' . 'Mojolicious::Plugin::PODViewer'
  ];
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    local *STDERR = $handle;
    $COMMAND->new(app => $app)->run(@$params);
  }

  # -p passed, -t passed, --class passed, --path is set to default.
  # static files and templates are inflated.
  # note $buffer;
  unlike $buffer, qr|Nothing to inflate|, 'right STDERR for -p';
  unlike $buffer, qr|Inflatable|,         'does not list inflatable classes';
  like $buffer,   qr|$params->[3]/partials/_head|,
    '-p, -t, --path and --class inflate all for these classes to --path';
  like $buffer, qr|mkdir.+$params->[3]/podviewer|,
    '-p, -t, --path and --class inflate all for these classes to --path';
  like $buffer, qr|exist.+$params->[3]/css/malka|,
    '-p, -t, --path and --class inflate to --path/css/malka';
  unlike $buffer, qr|mkdir.+$params->[3]/openapi|,
    '-p, -t and --class does not inflate to --path/**/openapi';
};

subtest Default => $default;
subtest Path    => $path;
subtest Class   => $class;
subtest Public  => $public;

subtest Public_and_Class => $public_and_class;

subtest Public_Templates_and_Class      => $public_templates_and_class;
subtest Public_Templates_Path_and_Class => $public_templates_path_and_class;

chdir path($Bin)->dirname;

done_testing;
