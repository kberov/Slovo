package Slovo;

use Mojo::Base 'Mojolicious';
use experimental 'signatures';
use Mojo::Util 'class_to_path';
use Mojo::File 'path';
use Slovo::Controller;
use Slovo::Validator;

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '2018.05.03';
our $CODENAME  = 'U+2C0C GLAGOLITIC CAPITAL LETTER DJERVI (Ⰼ)';
my $CLASS = __PACKAGE__;


has resources => sub {
  path($INC{class_to_path $CLASS})->sibling("$CLASS/resources")->realpath;
};

has validator => sub { Slovo::Validator->new };

# This method will run once at server start
sub startup($app) {
  $app->log->debug("Starting $CLASS $VERSION|$CODENAME");
  $app->controller_class('Slovo::Controller');
  $app->_load_config()->_load_pugins()->_default_paths();
  return $app;
}

sub _load_config($app) {
  my $etc     = $app->resources->child('etc');
  my $moniker = $app->moniker;
  my $mode    = $app->mode;

  # Load configuration from hash returned by "slovo.conf"
  my $config_file      = "$etc/$moniker.conf";
  my $mode_config_file = "$etc/$moniker.$mode.conf";
  $ENV{MOJO_CONFIG} //= -e $mode_config_file ? $mode_config_file : $config_file;

  my $config = $app->plugin('Config');
  for my $class (@{$config->{load_classes} // []}) {
    $app->load_class($class);
  }
  $app->secrets($config->{secrets});
  return $app;
}

sub _load_pugins($app) {

  # Namespaces to load plugins from
  # See /perldoc/Mojolicious#plugins
  # See /perldoc/Mojolicious/Plugins#PLUGINS
  $app->plugins->namespaces(['Mojolicious::Plugin', 'Slovo::Plugin']);
  foreach my $plugin (@{$app->config('plugins') // []}) {
    $app->log->debug(
              'Loading Plugin ' . (ref $plugin ? (keys %$plugin)[0] : $plugin));
    if (ref $plugin eq 'HASH') {
      $app->plugin(%$plugin);
    }
    elsif (!ref($plugin)) {
      $app->plugin($plugin);
    }
  }
  for my $setting (@{$app->config('sessions') // []}) {
    my ($a, $v) = (keys %$setting, values %$setting);
    $app->sessions->$a($v);
  }

  # Default "/perldoc" page is Slovo
  if (my $doc = $app->routes->lookup('perldocmodule')) {
    $doc->to->{module} = 'Slovo';
  }

  return $app;
}

sub _default_paths($app) {

  # Application/site specific "public" directory
  my $public = $app->resources->child('public')->to_string;
  unshift @{$app->static->paths}, $public if -d $public;

  # Application/site specific templates
  # See /perldoc/Mojolicious/Renderer#paths
  my $templates = $app->resources->child('templates')->to_string;
  push @{$app->renderer->paths}, $templates if -d $templates;

  return $app;
}

sub load_class ($app, $class) {
  state $log = $app->log;
  $log->debug("Loading $class");
  if (my $e = Mojo::Loader::load_class $class) {
    Carp::croak ref $e ? "Exception: $e" : "$class - Not found!";
  }
}

1;

=encoding utf8

=head1 NAME

Slovo - В началѣ бѣ Слово

=head1 SYNOPSIS

    Mojolicious::Commands->start_app('Slovo');

=head1 DESCRIPTION

This is a very early pre-pre-release!
L<Slovo> is a simple, installable and extensible L<Mojolicious>
L<CMS|https://en.wikipedia.org/wiki/Web_content_management_system>.

=head1 INSTALL

All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n -l ~/opt/slovo Slovo

We recommend the use of a L<Perlbrew|http://perlbrew.pl> environment.

If you already downloaded it and you have L<cpanm>.

    $ cpanm -l ~/opt/slovo Slovo-XXXX.XX.XX.tar.gz

Or even if you don't have C<cpanm>.

    tar zxf Slovo-XXXX.XX.XX.tar.gz
    cd  Slovo-XXXX.XX.XX
    perl Makefile.PL INSTALL_BASE=~/opt/slovo && make && make test && make install

=head1 USAGE

    cd /path/to/installed/slovo
    # see various options
    ./bin/slovo

=head1 CONFIGURATION, PATHS and UPGRADING

L<Slovo> is a L<Mojolicious> application which means that everything
applying to Mojolicious applies to it too. Slovo main configuration file is
in C<lib/Slovo/resourses/etc/slovo.conf>. You can use your own by setting
C<$ENV{MOJO_CONFIG}>. New routes can be described in C<routes.conf>. See
L<Mojolicious::Plugin::RoutesConfig> for details and examples.

C<$ENV{MOJO_HOME}> (where you installed Slovo) is automatically detected and
used. All paths, used in the application, then are expected to be its children.
You can add your own templates in C<$ENV{MOJO_HOME}/templates> and they will be
loaded and used with priority. You can theme your own instance of Slovo by just
copying C<$ENV{MOJO_HOME}/lib/Slovo/resources/templates> to
C<$ENV{MOJO_HOME}/templates> and modify them. You can add your own static files
to C<$ENV{MOJO_HOME}/public>. Last but not least, you can add your own classes
into C<$ENV{MOJO_HOME}/site/lib> and (why not) replace classes form Slovo.

With all the above, you can upgrade L<Slovo> by just installing new versions
over it and your files will not be touched. And of course, we know that you are
using versioning just in case anything goes wrong.

=head1 ATTRIBUTES

L<Slovo> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 resources

  push @{$app->static->paths}, $app->resources->child('public');

Returns a L<Mojo::File> instance for path L<Slovo/resources> next to where
C<Slovo.pm> is installed.

=head2 validator

  my $validator = $app->validator;
  $app          = $app->validator(Slovo::Validator->new);

Validate values, defaults to a L<Slovo::Validator> object.

  # Add validation check
  $app->validator->add_check(foo => sub {
    my ($v, $name, $value) = @_;
    return $value ne 'foo';
  });

  # Add validation filter
  $app->validator->add_filter(quotemeta => sub {
    my ($v, $name, $value) = @_;
    return quotemeta $value;
  });

=head1 METHODS

L<Slovo> inherits all methods from L<Mojolicious> and implements
the following new ones.

=head2 load_class

A convenient wrapper with check for L<Mojo::Loader/load_class>.
Loads a class and croaks if something is wrong. This could be a helper.

=head2 startup

    my $app = Slovo->new->startup;

Starts the application, sets defaults, reads configuration file(s) and returns
the application instance.

=head1 BUGS

Please open issues at L<https://github.com/kberov/Slovo/issues>.

=head1 SUPPORT

Please open issues at L<https://github.com/kberov/Slovo/issues>.

=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    berov ат cpan точка org
    http://i-can.eu

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.	

The full text of the license can be found in the
LICENSE file included with this module.

=head1 TODO

Add simplemde-markdown-editor to the distro and use it to prepare markdown as
html in the browser.
  (https://github.com/sparksuite/simplemde-markdown-editor)
  (https://github.com/Inscryb/inscryb-markdown-editor)

Consider addding also ContentTools as the default WYSIWIG html editor
  (https://github.com/GetmeUK/ContentTools)

Consider (preferred) using Mithril as frontend framework for building UI
together with Pure CSS for styling.
  (https://github.com/MithrilJS/mithril.js)
  (https://github.com/pure-css/pure)

Consider using L<DataTables|https://datatables.net/> jQuery plugin for the
administrative panel.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>

=cut


