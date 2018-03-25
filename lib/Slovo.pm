package Slovo;
use Mojo::Base 'Mojolicious';
use experimental 'signatures';
use Mojo::Util 'class_to_path';
use Mojo::File 'path';

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '2018.03.24';
our $CODENAME  = 'U+2C0A GLAGOLITIC CAPITAL LETTER INITIAL IZHE (Ⰺ)';
my $CLASS = __PACKAGE__;

has resources_path => sub {
  path($INC{class_to_path $CLASS})->sibling("$CLASS/resources")->realpath;
};

# This method will run once at server start
sub startup($app) {
  $app->_load_pugins()->_default_paths();
  return $app;
}

sub _load_pugins($app) {
  my $etc     = $app->resources_path->child('etc');
  my $moniker = $app->moniker;
  my $mode    = $app->mode;

  # Load configuration from hash returned by "slovo.conf"
  my $config_file      = "$etc/$moniker.conf";
  my $mode_config_file = "$etc/$moniker.$mode.conf";
  $ENV{MOJO_CONFIG} ||= -e $mode_config_file ? $mode_config_file : $config_file;
  my $config = $app->plugin('Config');

  # Namespaces to load plugins from
  # See /perldoc/Mojolicious#plugins
  # See /perldoc/Mojolicious/Plugins#PLUGINS
  $app->plugins->namespaces(['Mojolicious::Plugin', 'Slovo::Plugin']);
  my $plugins = $app->config('plugins') || [];
  foreach my $plugin (@$plugins) {
    $app->log->debug(
              'Loading Plugin ' . (ref $plugin ? (keys %$plugin)[0] : $plugin));
    if (ref $plugin eq 'HASH') {
      $app->plugin(%$plugin);
    }
    elsif ($plugin) {
      $app->plugin($plugin);
    }
  }
  return $app;
}

sub _default_paths($app) {

  # Use also the installable "public" directory
  push @{$app->static->paths}, $app->resources_path->child('public');

  # Application/site specific templates
  # See /perldoc/Mojolicious/Renderer#paths
  push @{$app->renderer->paths}, $app->resources_path->child('templates');

  return $app;
}

1;

=encoding utf8

=head1 NAME

Slovo - В началѣ бѣ Слово

=head1 SYNOPSIS

    Mojolicious::Commands->start_app('Slovo');

=head1 DESCRIPTION

This is a very early pre-pre-release!
L<Slovo> is a tiny L<Mojolicious>
L<CMS|https://en.wikipedia.org/wiki/Web_content_management_system> which can be
extended in various ways.

=head1 INSTALL

All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Slovo

We recommend the use of a L<Perlbrew|http://perlbrew.pl> environment.

If you already downloaded it and you have L<cpanm> already.

    $ cpanm -l /install/target/slovo Slovo-XXXX.XX.XX.tar.gz

Or even if you don't have C<cpanm>.

    tar zxf Slovo-XXXX.XX.XX.tar.gz
    cd  Slovo-XXXX.XX.XX
    perl Makefile.PL INSTALL_BASE=~/opt/slovo && make && make test && make install

=head1 USAGE

    cd /path/to/installed/slovo
    # see various options
    ./bin/slovo

=head1 CONFIGURATION

L<Slovo> configuration files are in C<lib/Slovo/resourses/etc>. New routes can
be described in C<routes.conf>. See L<Mojolicious::Plugin::RoutesConfig> for
details and examples.

=head1 ATTRIBUTES

L<Slovo> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 resources_path

  push @{$app->static->paths}, $app->resources_path->child('public');

Returns a L<Mojo::File> instance for path L<Slovo/resources> next to where
C<Slovo.pm> is installed.

=head1 METHODS

L<Slovo> inherits all methods from L<Mojolicious> and implements
the following new ones.

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
    N/A
    berov@cpan.org
    http://i-can.eu

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.	

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>

=cut


