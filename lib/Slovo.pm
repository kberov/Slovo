package Slovo;

# we want to use many recent native features in modern perl, available in
# 5.012+. Here are some of them which we switch ON on the next few lines:
# * unicode strings: see /perldoc/feature#The-unicode_strings-feature
# * my/state/our sub foo syntax: see /perldoc/feature#The-lexical_subs-feature
# * signatures /perldoc/feature#The-signatures-feature
use Mojo::Base 'Mojolicious', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

use Mojo::Util 'class_to_path';
use Mojo::File 'path';
use Mojo::Collection 'c';
use Slovo::Controller;
use Slovo::Validator;

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '2019.07.07';
our $CODENAME  = 'U+2C13 GLAGOLITIC CAPITAL LETTER RITSI (Ⱃ)';
my $CLASS = __PACKAGE__;

has resources => sub {
  path($INC{class_to_path $CLASS})->sibling("$CLASS/resources")->realpath;
};
has validator => sub { Slovo::Validator->new };

# We prefer $MOJO_HOME to be the folder where bin or script resides.
has home => sub {
  if ($ENV{MOJO_HOME}) { return Mojo::Home->new($ENV{MOJO_HOME}); }
  my $r = Mojo::Home->new($INC{class_to_path $CLASS})->dirname->to_abs;
  my $m = $_[0]->moniker;
  while (($r = $r->dirname) && @{$r->to_array} > 2) {
    if (-x $r->child("bin/$m") || -x $r->child("script/$m")) {
      return $r;
    }
  }
  return shift->SUPER::home;
};

# This method will run once at server start
sub startup($app) {
  $app->log->debug("Starting $CLASS $VERSION|$CODENAME");
  $app->controller_class('Slovo::Controller');
  $app->commands->namespaces(
    ['Slovo::Command::Author', 'Slovo::Command', 'Mojolicious::Command']);
  ## no critic qw(Subroutines::ProtectPrivateSubs)
  $app->hook(before_dispatch => \&_before_dispatch);
  $app->hook(around_dispatch => \&_around_dispatch);
  $app->_set_routes_attrs->_load_config->_load_pugins->_default_paths->_add_media_types();
  return $app;
}

sub _before_dispatch($c) {
  state $guest       = $c->users->find_by_login_name('guest');
  state $auth_config = c(@{$c->config('plugins')})->first(sub {
    ref $_ eq 'HASH' and exists $_->{Authentication};
  });
  state $session_key     = $auth_config->{Authentication}{session_key};
  state $current_user_fn = $auth_config->{Authentication}{current_user_fn};
  unless ($c->session->{$session_key}) {

    #set the guest user as default to always have a user
    $c->$current_user_fn($guest);
  }
  return;
}

# This code is executed on every request, so we try to save as much as possible
# method calls.
sub _around_dispatch ($next, $c) {
  state $app   = $c->app;
  state $droot = $app->config('domove_root');

  state $s_paths = $app->static->paths;
  state $r_paths = $app->renderer->paths;
  my $dom;
  eval { $dom = $c->domove->find_by_host($c->host_only) }
    || die 'No such Host ('
    . $c->host_only
    . ')! Looks like a Proxy Server misconfiguration, readonly'
    . " database file or a missing domain alias in table domove.\n";

  # Use domain specific public and templates' paths with priority.
  unshift @{$s_paths}, "$droot/$dom->{domain}/public";
  unshift @{$r_paths}, "$droot/$dom->{domain}/templates";
  $app->defaults(domain => $dom);
  $next->();
  shift @{$s_paths};
  shift @{$r_paths};
  return;
}

sub _load_config($app) {
  my $etc     = $app->resources->child('etc');
  my $moniker = $app->moniker;
  my $mode    = $app->mode;
  my $home    = $app->home;

  # Load configuration from hash returned by "slovo.conf"
  my $file      = $etc->child("$moniker.conf");
  my $mode_file = $etc->child("$moniker.$mode.conf");
  $ENV{MOJO_CONFIG}
    //= (-e $app->home->child("$moniker.$mode.conf")
      && $app->home->child("$moniker.$mode.conf"))
    || (-e $app->home->child("$moniker.conf") && $app->home->child("$moniker.conf"))
    || (-e $mode_file ? $mode_file : $file);

  my $config = $app->plugin('Config');
  for my $class (@{$config->{load_classes} // []}) {
    $app->load_class($class);
  }
  $app->secrets($config->{secrets});

  # Enable response compression
  if ($config->{response_compression}) {
    $app->renderer->compress(1);
  }

  for my $setting (@{$config->{sessions} // []}) {
    my ($a, $v) = (keys %$setting, values %$setting);
    $app->sessions->$a($v);
  }

  return $app;
}

sub _load_pugins($app) {

  # Namespaces to load plugins from
  # See /perldoc/Mojolicious#plugins
  # See /perldoc/Mojolicious/Plugins#PLUGINS
  $app->plugins->namespaces(['Slovo::Plugin', 'Slovo', 'Mojolicious::Plugin']);
  my $plugins = $app->config('plugins') // [];
  push @$plugins, qw(DefaultHelpers TagHelpers);
  foreach my $plugin (@$plugins) {
    my $name = (ref $plugin ? (keys %$plugin)[0] : $plugin);

    # $app->log->debug('Loading Plugin ' . $name);
    # some plugins return $self and we are going to abuse this.
    my $plug;
    if (ref $plugin eq 'HASH') {
      my $value = (values %$plugin)[0];
      $plug = $app->plugin($name => ref $value eq 'CODE' ? $value->() : $value);
    }
    elsif (!ref($plugin)) {
      $plug = $app->plugin($name);
    }

    # Make OpenAPI specification allways available!
    if ($name eq 'OpenAPI') {
      $app->helper(
        openapi_spec => sub ($c_or_app, $path = '/') {
          $plug->validator->get($path);
        });
    }
  }

  return $app;
}

sub _default_paths($app) {

  # Fallback "public" directory
  my $public = $app->resources->child('public')->to_string;
  unshift @{$app->static->paths}, $public if -d $public;

  # Fallback templates directory
  # See /perldoc/Mojolicious/Renderer#paths
  my $templates = $app->resources->child('templates')->to_string;
  unshift @{$app->renderer->paths}, $templates if -d $templates;
  return $app;
}


#Set Mojolicious::Routes object attributes and types
sub _set_routes_attrs ($app) {
  my $r = $app->routes;
  push @{$r->base_classes}, $app->controller_class;
  $r->namespaces($r->base_classes);
  my $w = qr/[\w\-]+/;
  @{$r->types}{qw(lng str cel fl_token)}
    = (qr/[A-z]{2}(?:\-[A-z]{2})?/a, $w, $w, qr/[a-f0-9]{40}/);
  return $app;
}

# Add more media types
sub _add_media_types($app) {
  $app->types->type(woff  => ['application/font-woff',  'font/woff']);
  $app->types->type(woff2 => ['application/font-woff2', 'font/woff2']);
  return $app;
}

sub load_class ($app, $class) {
  state $log = $app->log;

  # $log->debug("Loading $class");
  if (my $e = Mojo::Loader::load_class $class) {
    Carp::croak ref $e ? "Exception: $e" : "$class - Not found!";
  }
}

1;

=encoding utf8

=head1 NAME

Slovo - Искони бѣ Слово

=head1 SYNOPSIS

Install Slovo locally with all dependencies in less than two minutes

    date
    curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -q -n -l \
    ~/opt/slovo Slovo
    date

Run slovo for the first time in debug mode

    ~/opt/slovo/bin/slovo daemon

Visit L<http://127.0.0.1:3000>.
For help visit L<http://127.0.0.1:3000/perldoc>.

=head1 DESCRIPTION

L<Slovo> is a simple to install and extensible L<Mojolicious>
L<CMS|https://en.wikipedia.org/wiki/Web_content_management_system>
with nice core features like:

=over

=item On the fly generation of static pages under Apache/CGI – perfect for
cheap shared hosting and blogging – BETA

=item Multi-domain support - DONE;

=item Multi-language pages - DONE;

=item Cached published pages and content - DONE;

=item Multi-user support - DONE;

=item User onboarding - BETA;

=item User sign in - DONE;

=item Managing pages, content, domains, users - WIP;

=item Managing groups - BASIC;

=item Multiple groups per user - DONE;

=item Ownership and permissions management per page and it's content - DONE;

=item Automatic 301 and 308 (Moved Permanently) redirects for renamed pages
and content - DONE;

=item Embedded fonts for displaying all
L<Azbuka|https://en.wikipedia.org/wiki/Cyrillic_script> and
L<Glagolitsa|https://en.wikipedia.org/wiki/Glagolitic_script> characters -
DONE;

=item OpenAPI 2.0 (Swagger) REST API - BASIC;

=item Trumbowyg - L<A lightweight WYSIWYG editor|https://alex-d.github.io/Trumbowyg/>.

=item Example startup scripts for slovo and slovo_minion services
for L<systemd|https://freedesktop.org/wiki/Software/systemd/>, L<Apache
2.4|https://httpd.apache.org/docs/2.4/> and NGINX vhost configuration files.

=item and more to come…

=back

This is a usable release!

By default Slovo comes with SQLite database, but support for PostgreSQL or
MySQL is about to be added when needed. It is just a question of making
compatible and/or translating some limited number of SQL queries to the
corresponding SQL dialects. Contributors are wellcome.

The word "slovo" (слово) has one unchanged meaning during the last millenium in
all slavic languages. It is actually one language that started splitting apart
less than one thousand years ago. The meaning is "word" – the God's word (when
used with capital letter). Hence the self-naming of this group of people
C<qr/sl(o|a)v(e|a|i)n(i|y|e)/> - people who have been given the God's word or
people who can speak. All others were considered "mute", hense the naming
(немци)...

=head1 INSTALL

All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n -l ~/opt/slovo Slovo

We recommend the use of a L<Perlbrew|http://perlbrew.pl> environment.

If you already downloaded it and you have L<cpanm>.

    $ cpanm -l ~/opt/slovo Slovo-XXXX.XX.XX.tar.gz

Or even if you don't have C<cpanm>, but you need to install dependencies first.

    tar zxf Slovo-XXXX.XX.XX.tar.gz
    cd  Slovo-XXXX.XX.XX
    perl Makefile.PL INSTALL_BASE=~/opt/slovo && make && make test && make install

=head1 USAGE

    cd /path/to/installed/slovo
    # ...and see various options
    ./bin/slovo

=head1 CONFIGURATION, PATHS and UPGRADING

L<Slovo> is a L<Mojolicious> application which means that everything
applying to Mojolicious applies to it too. Slovo main configuration file is
in C<lib/Slovo/resourses/etc/slovo.conf>. You can use your own by setting
C<$ENV{MOJO_CONFIG}> or by just copying C<slovo.conf> to $ENV{MOJO_HOME} and
modify it as you wish. New routes can be described in C<routes.conf>. See
L<Mojolicious::Plugin::RoutesConfig> for details and examples.

C<$ENV{MOJO_HOME}> (L<where you installed Slovo|/home>) is automatically detected and
used. All paths, used in the application, are expected to be its children.  You
can add your own templates in C<$ENV{MOJO_HOME}/templates> and they will be
loaded and used with priority. You can theme your own instance of Slovo by just
copying C<$ENV{MOJO_HOME}/lib/Slovo/resources/templates> to
C<$ENV{MOJO_HOME}/templates> and modify them. You can add your own static files
to C<$ENV{MOJO_HOME}/public>.

You can have separate static files and templates per domain under
C<$ENV{MOJO_HOME}/domove/your.domain/public>,
C<$ENV{MOJO_HOME}/domove/your.other.domain/templates>, etc. See
C<$ENV{MOJO_HOME}/domove/localhost> for example.

Last but not least, you can add your own classes into
C<$ENV{MOJO_HOME}/site/lib> and (why not) replace entirely some Slovo classes
or just extend them. C<$ENV{MOJO_HOME}/bin/slovo> will automatically load them.

With all the above, you can upgrade L<Slovo> by just installing new versions
over it and your files will not be touched. And of course, we know that you are
using versioning just in case anything goes wrong. See L</home>.

=head1 ATTRIBUTES

L<Slovo> inherits all attributes from L<Mojolicious> and implements
the following new ones.

=head2 home

L<Slovo> detects where B<home> is not like L<Mojo::Home> by where
C<lib/Mojolicous.pm> is but by where the C<script/> or C<bin/> folder resides
starting from where C<lib/Slovo.pm> is and going up the tree. If in one of
these folders there is C<$app-E<gt>moniker>, then the upper folder is the home.

Examples:

    berov@Skylake:Slovo$ pwd
    /home/berov/opt/dev/Slovo
    berov@Skylake:Slovo$ perl script/slovo eval 'say app->home'
    /home/berov/opt/dev/Slovo

    berov@Skylake:Slovo$ cpanm . -n -l ~/opt/t.com/slovo
    --> Working on .
    Configuring /home/berov/opt/dev/Slovo ... OK
    Building Slovo-v2019.06.09 ... OK
    Successfully installed Slovo-v2019.06.09
    1 distribution installed

    berov@Skylake:t.com$ pwd
    /home/berov/opt/t.com
    berov@Skylake:t.com$ slovo/bin/slovo eval 'say app->home'
    /home/berov/opt/t.com/slovo

    berov@Skylake:t.com$ pwd
    /home/berov/opt/t.com
    berov@Skylake:t.com$ perl -Islovo/lib/perl5 -MSlovo -E 'say Slovo->new->home'
    /home/berov/opt/t.com/slovo

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

Starts the application. Adds hooks, prepares C<$app-E<gt>routes> for use, loads
configuration files and applies settings from them, loads plugins, sets default
paths, and returns the application instance.

=head1 HOOKS

Slovo adds custom code to the following hooks.

=head2 around_dispatch

On each request we determine the current host and modify the static and
renderer paths accordingly. This is how the multi-domain support works.

=head2 before_dispatch

On each request we check if we have logged in user and set the current user to
C<guest> if we don't. This way every part of the application (including newly
developed plugins) can count on having a current user. It is used for
determining the permissions for any resource in the application. The user is
available as C<$c-E<gt>user>.

=head1 HELPERS

Slovo implements the following helpers.

=head2 openapi_spec

We need to have our openapi API specification always at hand as a unified
source of truth so here it is.

    #anywhere via $app or $c, even not via a REST call
    state $columns =
        $c->openapi_spec('/paths/~1страници/get/parameters/3/default');
    [
      "id",
      "pid",
      "alias",
      "title",
      "is_dir"
    ]

=head1 BUGS, SUPPORT, COMMIT, DISCUSS

=for html <a href="https://travis-ci.org/kberov/Slovo"><img src="https://travis-ci.org/kberov/Slovo.svg?branch=master"></a>

Please use issues at L<GitHub|https://github.com/kberov/Slovo/issues>, fork the
project and make pull requests.


=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    berov на cpan точка org
    http://i-can.eu

=head1 CONTRIBUTORS

Ordered by time of first commit.

=over

=item * MANWAR (Mohammad S Anwar)

=item * KABANOID (Mikhail Katasonov)

=item * 0xAF (Stanislav Lechev)

=back

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.

The full text of the license can be found in the
LICENSE file included with this module.

This distribution contains other free software which belongs to their
respective authors.

=head1 TODO

Considerably improve the Adminiastration UI - now it is quite simplistic and
lacks essential features.

Add simplemde-markdown-editor to the distro and use it to prepare markdown as
html in the browser.
  (https://github.com/sparksuite/simplemde-markdown-editor)
  (https://github.com/Inscryb/inscryb-markdown-editor)

Consider using Mithril or Dojo or something light as frontend framework for
building UI. We already use jQuery from Mojolicious.
  (https://github.com/MithrilJS/mithril.js), (https://dojo.io/)

Consider using L<DataTables|https://datatables.net/> jQuery plugin for the
administrative panel.

=head1 SEE ALSO

L<Slovo::Plugin::TagHelpers>, L<Slovo::Plugin::DefaultHelpers>,
L<Slovo::Validator>, L<Mojolicious>, L<Mojolicious::Guides>

=cut


