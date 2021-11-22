package Slovo;
use feature ':5.26';
use Mojo::Base 'Mojolicious', -signatures;

use Mojo::Util 'class_to_path';
use Mojo::File 'path';
use Mojo::Collection 'c';
use Slovo::Controller::Auth;
use Slovo::Validator;
use Slovo::Cache;
use Time::Piece;

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '2021.11.22';
our $CODENAME  = 'U+2C14 GLAGOLITIC CAPITAL LETTER SLOVO (Ⱄ)';
my $CLASS = __PACKAGE__;

has resources => sub {
  path($INC{class_to_path $CLASS})->sibling("$CLASS/resources")->realpath;
};
has validator => sub { Slovo::Validator->new };

# We prefer $MOJO_HOME to be the folder where the folders bin or script
# reside.
has home => sub {
  if ($ENV{MOJO_HOME}) { return Mojo::Home->new($ENV{MOJO_HOME}); }
  my $r = Mojo::Home->new($INC{class_to_path $CLASS})->dirname->to_abs;
  my $m = $_[0]->moniker;
  while (($r = $r->dirname) && @{$r->to_array} > 2) {
    if (-x $r->child("bin/$m") || -x $r->child("script/$m")) {
      return $r;
    }
  }
  return $_[0]->SUPER::home;
};

# Writes to $home/log/slovo.log if $home/log/ exists and is writable.
has log => sub {
  my $self = shift;

  my $mode = $self->mode;
  my $log  = Mojo::Log->new;

  my $home = $self->home;
  if (-d $home->child('log') && -w _) {
    $log->path($home->child('log', $self->moniker . ".log"));
  }

  # Reduced log output outside of development mode
  return $log->level($ENV{MOJO_LOG_LEVEL}) if $ENV{MOJO_LOG_LEVEL};
  return $mode eq 'development' ? $log : $log->level('info');
};

# This method will run once at server start
sub startup ($app) {
  $app->log->debug("Starting $CLASS $VERSION|$CODENAME");
  $app->controller_class('Slovo::Controller');
  $app->commands->namespaces(
    ['Slovo::Command::Author', 'Slovo::Command', 'Mojolicious::Command']);
  ## no critic qw(Subroutines::ProtectPrivateSubs)
  $app->hook(around_action   => \&_around_action);
  $app->hook(around_dispatch => \&_around_dispatch);
  $app->hook(before_dispatch => \&_before_dispatch);
  $app->_set_routes_attrs->_load_config->_load_pugins->_default_paths->_add_media_types();
  my $cache = Slovo::Cache->new();
  $app->renderer->cache($cache);
  $app->routes->cache($cache);
  $app->defaults(

    # layout => 'default'
    boxes            => $app->openapi_spec('/parameters/box/enum'),
    data_formats     => $app->openapi_spec('/parameters/data_format/enum'),
    data_types       => $app->openapi_spec('/parameters/data_type/enum'),
    lang             => 'bg-bg',
    languages        => $app->languages,    # /parameters/language/enum
    page_types       => $app->openapi_spec('/parameters/page_type/enum'),
    permissions      => $app->openapi_spec('/parameters/permissions/enum'),
    stranici_columns =>
      $app->openapi_spec('/paths/~1stranici/get/parameters/4/items/enum'),
  );
  return $app;
}

sub _before_dispatch ($c) {
  state $guest       = $c->users->find_by_login_name('guest');
  state $auth_config = c(@{$c->config('load_plugins')})->first(sub {
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

# Make some variables available to the templates being rendered, so
# these do not need to be set in the actions.
sub _around_action ($next, $c, $action, $last) {
  if ($last && $c->current_route !~ /^api\./) {
    my $stash = $c->stash;
    $stash->{l}    //= $c->language;    # current language of the text being edited
    $stash->{user} //= $c->user;        # current user
  }
  return $next->();
}

# This code is executed on every request, so we try to save as much as possible
# method calls.
sub _around_dispatch ($next, $c) {
  state $app  = $c->app;
  state $root = $app->config('domove_root');

  state $s_paths = $app->static->paths;
  state $r_paths = $app->renderer->paths;
  state $cache   = $app->renderer->cache;
  my $dom
    = eval { $c->domove->find_by_host($c->host_only) }
    || die 'No such Host ('
    . $c->host_only
    . ')! Looks like a Proxy Server misconfiguration, readonly'
    . " database file or a missing domain alias in table domove.\n";

  # Use domain specific public and templates' paths with priority.
  unshift @{$s_paths}, "$root/$dom->{domain}/public";
  if (my $tpls = $dom->{templates}) {

    # absolute path
    if ($tpls =~ m|^/| && -d $tpls) {
      unshift @{$r_paths}, $tpls;
    }
    else {
      unshift @{$r_paths}, "$root/$dom->{domain}/templates";

      # try to find the relative path to the theme in the list of paths
      for my $path (@{$r_paths}) {
        if (-d "$path/$tpls") {
          unshift @{$r_paths}, "$path/$tpls";
          last;
        }
      }
    }
  }
  else {
    unshift @{$r_paths}, "$root/$dom->{domain}/templates";
  }

  # Templates and routes are cached per domain. By the 'key_prefix' trick we
  # can provide different templates with the same name to the renderer. This is
  # how a long running application can switch to different themes per domain
  # and have different templates although looking like having "the same" path.
  # This is transparent for the renderer.
  $cache->key_prefix($dom->{domain});
  $c->stash(domain => $dom);
  $next->();
  shift @{$s_paths};
  shift @{$r_paths};
  return;
}

sub _load_config ($app) {
  my $etc     = $app->resources->child('etc');
  my $moniker = $app->moniker;
  my $mode    = $app->mode;
  my $home    = $app->home;

  # Load configuration from hash returned by "slovo.conf"
  my $file      = $etc->child("$moniker.conf");
  my $mode_file = $etc->child("$moniker.$mode.conf");
  $ENV{MOJO_CONFIG}
    //= (-e $home->child("$moniker.$mode.conf") && $home->child("$moniker.$mode.conf"))
    || (-e $home->child("$moniker.conf") && $home->child("$moniker.conf"))
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

sub _load_pugins ($app) {

  # Namespaces to load plugins from
  # See /perldoc/Mojolicious#plugins
  # See /perldoc/Mojolicious/Plugins#PLUGINS
  $app->plugins->namespaces(['Slovo::Plugin', 'Slovo', 'Mojolicious::Plugin']);
  my $plugins = $app->config('load_plugins') // [];
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
  $app->routes->any('/*page_alias')->to('stranici#execute')->name('catch_all');

  return $app;
}

sub _default_paths ($app) {

  # Fallback "public" directory
  push @{$app->static->paths}, $app->resources->child('public')->to_string;

  # Fallback templates directory
  # See /perldoc/Mojolicious/Renderer#paths
  push @{$app->renderer->paths}, $app->resources->child('templates')->to_string;

  # Current heme
  return $app;
}


# Set Mojolicious::Routes object attributes and types
# See Mojolicious::Routes#base_classes
# See Mojolicious::Guides::Routing#Placeholder-types
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
sub _add_media_types ($app) {
  $app->types->type(woff  => ['application/font-woff',  'font/woff']);
  $app->types->type(woff2 => ['application/font-woff2', 'font/woff2']);
  return $app;
}

sub load_class ($app, $class) {

  # state $log = $app->log;
  # $log->debug("Loading $class");
  if (my $e = Mojo::Loader::load_class $class) {
    Carp::croak ref $e ? "Exception: $e" : "$class - Not found!";
  }
  return;
}

1;

=encoding utf8

=head1 NAME

Slovo - Искони бѣ Слово

=head1 SYNOPSIS

Install Slovo locally with all dependencies in less than two minutes

    time curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org \
    -q -n -l ~/opt/slovo Slovo

Run slovo for the first time in debug mode

   morbo ~/opt/slovo/bin/slovo

Visit L<http://127.0.0.1:3000>.
For help visit L<http://127.0.0.1:3000/perldoc>.

=head1 DESCRIPTION

L<Slovo> is a simple to install and extensible L<Mojolicious>
L<CMS|https://en.wikipedia.org/wiki/Web_content_management_system>
with nice core features, listed below. 

This is a usable release, yet B<full of creeping bugs> and B<half-implemented
pieces>! The project is in active development, so expect often breaking changes.

=over

=item * On the fly generation of static pages under Apache/CGI – perfect for
cheap shared hosting and blogging – BETA;

=item * Multi-domain support - BETA;

=item * Multi-language pages - WIP;

=item * Cached published pages and content - DONE;

=item * Multi-user support - DONE;

=item * User onboarding - WIP;

=item * User sign in - DONE;

=item * Managing pages, content, domains, users - WIP;

=item * Managing groups - BASIC;

=item * Multiple groups per user - DONE;

=item * Ownership and permissions management per page and it's content - BETA;

=item * Automatic 301 and 308 (Moved Permanently) redirects for renamed pages
and content - DONE;

=item * Embedded fonts for displaying all
L<Azbuka|https://en.wikipedia.org/wiki/Cyrillic_script> and
L<Glagolitsa|https://en.wikipedia.org/wiki/Glagolitic_script> characters -
DONE;

=item * OpenAPI 2/3.0 (Swagger) REST API - BASIC;

=item * Embedded Trumbowyg - L<A lightweight WYSIWYG editor|https://alex-d.github.io/Trumbowyg/>;

=item * Embedded Editor.md - L<The open source embeddable online markdown editor
(component), based on CodeMirror & jQuery &
Marked|http://editor.md.ipandao.com/>;

=item * Example startup scripts for slovo and slovo_minion services
for L<systemd|https://freedesktop.org/wiki/Software/systemd/>, L<Apache
2.4|https://httpd.apache.org/docs/2.4/> and NGINX vhost configuration files.

=item * Inflatable embedded themes support - BETA;

=item * and more to come…

=back

By default Slovo comes with SQLite database, but support for PostgreSQL or
MySQL is about to be added when needed. It is just a question of making
compatible and/or translating some limited number of SQL queries to the
corresponding SQL dialects. Contributors are welcome.

The word "slovo" (слово) has one unchanged meaning during the last millennium
among all slavic languages. It is actually one language that started splitting
apart less than one thousand years ago. The meaning is "word" – the God's word
(when used with capital letter). Hence the self-naming of this group of people
C<qr/sl(o|a)v(e|a|i)n(i|y|e)/> - people who have been given the God's word or
people who can speak. All others were considered "mute", hence the naming
(немци)...

=head1 INSTALL

All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n -l ~/opt/slovo Slovo

We recommend the use of a L<Perlbrew|http://perlbrew.pl> environment.

If you already downloaded it and you have L<cpanm>.

    $ cpanm -l ~/opt/slovo Slovo-XXXX.XX.XX.tar.gz

Or even if you don't have C<cpanm>. Note that you need to install dependencies first.
Set C<INSTALL_BASE>, remove old Slovo installation, make, test, install, create
data directory for sqlite database and run slovo to see available commands.

    tar zxf Slovo-XXXX.XX.XX.tar.gz
    cd  Slovo-XXXX.XX.XX
    INSTALL_BASE=~/opt/slovo && rm -rf $INSTALL_BASE && make distclean; \
    perl Makefile.PL INSTALL_BASE=$INSTALL_BASE && make && make test && make install \
    && $INSTALL_BASE/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});' \
    && $INSTALL_BASE/bin/slovo

Use cpanm to install or update into a custom location as self contained application and
run slovo to see how it's going.

    # From metacpan. org
    export PREFIX=~/opt/slovo;
    cpanm -M https://cpan.metacpan.org -n --self-contained -l $PREFIX Slovo \
    $PREFIX/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});' \
    $PREFIX/bin/slovo

    # From the directory where you unpacked Slovo
    export PREFIX=~/opt/slovo;
    cpanm . -n --self-contained -l $PREFIX Slovo
    $PREFIX/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});'
    $PREFIX/bin/slovo

Start the development server and open a browser

    morbo ./script/slovo -l http://*:3000 & sleep 1 exo-open http://localhost:3000

=head1 USAGE

    cd /path/to/installed/slovo
    # ...and see various options
    ./bin/slovo

=head1 CONFIGURATION, PATHS and UPGRADING

L<Slovo> is a L<Mojolicious> application which means that everything
applying to Mojolicious applies to it too. Slovo main configuration file is
in C<lib/Slovo/resourses/etc/slovo.conf>. You can use your own by setting
C<$ENV{MOJO_CONFIG}> or by just copying C<slovo.conf> to $ENV{MOJO_HOME} and
modify it as you wish. Routes can be added or removed in C<routes.conf>. See
L<Mojolicious::Plugin::RoutesConfig> for details and examples. New plugins can
be added per deployment in C<plugins> section in C<slovo.conf>.

C<$ENV{MOJO_HOME}> (L<where you installed Slovo|/home>) is automatically
detected and used. All paths, used in the application, are expected to be its
children. You can add your own templates in C<$ENV{MOJO_HOME}/templates> and
they will be loaded and used with priority. You can theme your own instance of
Slovo by just copying C<$ENV{MOJO_HOME}/lib/Slovo/resources/templates> to
C<$ENV{MOJO_HOME}/templates> and modify them. You can add your own static files
to C<$ENV{MOJO_HOME}/public>. You can create custom themes by forking
L<Slovo::Themes::Malka> and using it as a starting point.

You can have separate static files and templates per domain under
C<$ENV{MOJO_HOME}/domove/your.domain/public>,
C<$ENV{MOJO_HOME}/domove/your.other.domain/templates>, etc. See
C<$ENV{MOJO_HOME}/domove/localhost> for example.

You can switch between different themes by just selecting the theme in the
form for editing domains.

Last but not least, you can add your own classes into
C<$ENV{MOJO_HOME}/site/lib> and (why not) replace entirely some Slovo classes
or just extend them. C<$ENV{MOJO_HOME}/bin/slovo> will load them with priority.

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
these folders there is a C<slovo> executable, then the upper folder is the
home.

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

=head2 log

Overrides L<Mojolicious/log>. Logs to C<self-E<gt>home-E<gt>child('log/slovo.log')>
if C<$self-E<gt>home-E<gt>child('log')> exists and is writable. Oderwise writes to
STDERR. The log-level will default to either the C<MOJO_LOG_LEVEL> environment
variable, C<debug> if the "mode" is C<development>, or C<info> otherwise.

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

  for my $class (@{$config->{load_classes} // []}) {
    $app->load_class($class);
  }

=head2 startup

Starts the application. Adds hooks, prepares C<$app-E<gt>routes> for use, loads
configuration files and applies settings from them, loads plugins, sets default
paths, and returns the application instance. See also L<Mojolicious/startup>.

=head1 HOOKS

Slovo adds custom code to the following hooks.

=head2 around_action

On each request we set the following variables in the stash so they are
available in the respective templates. Here they are:

    $stash->{l}         //= $c->language;     # current language
    $stash->{user}      //= $c->user;         # current user

=head2 around_dispatch

On each request we determine the current host and modify the static and
renderer paths accordingly. This is how each domain has its own templates and
static files.

Also if the C<templates> field for the current domain is not empty, we
determine from it the templates root for the theme to be used for this domain
during this request. This is how the themes support for multiple domains in one
L<Slovo> instance work.

It is also important to note that in a long running application (not CGI) the
templates are cached in memory and the relative path from the current
templates root to each template is used as the key in L<Mojo::Cache> cache. We
had to implement L<Slovo::Cache/key_prefix> to be able to differentiate between
templates having the same names, but found in different paths. All this is
possible thanks to L<Mojolicious>'s well decoupled components.

Example: Let's suppose that the domain L<https://слово.бг> has the field
'templates' value set to C<themes/malka> (малка==small f. in Bulgarian).

Renderer paths before the check is performed:

  [
    "/home/berov/opt/dev/Slovo/templates",
    "/home/berov/perl5/perlbrew/perls/perl-5.28.2/lib/site_perl/5.28.2/Mojolicious/Plugin/Minion/resources/templates",
    "/home/berov/opt/dev/Slovo/lib/Slovo/resources/templates"
  ]

Static paths before the check:

  [
    "/home/berov/opt/dev/Slovo/public",
    "/home/berov/perl5/perlbrew/perls/perl-5.28.2/lib/site_perl/5.28.2/Mojolicious/Plugin/Minion/resources/public",
    "/home/berov/opt/dev/Slovo/lib/Slovo/resources/public"
  ]

Renderer paths after the check is performed. The first path in the list will be
used with priority:

  [
    "/home/berov/opt/dev/Slovo/lib/Slovo/resources/templates/themes/malka", # if exists!
    "/home/berov/opt/dev/Slovo/domove/xn--b1arjbl.xn--90ae/templates", # if exists!
    "/home/berov/opt/dev/Slovo/templates",
    "/home/berov/perl5/perlbrew/perls/perl-5.28.2/lib/site_perl/5.28.2/Mojolicious/Plugin/Minion/resources/templates",
    "/home/berov/opt/dev/Slovo/lib/Slovo/resources/templates"
  ]

Static paths after the check:

  [
    "/home/berov/opt/dev/Slovo/domove/xn--b1arjbl.xn--90ae/public", # if exists!
    "/home/berov/opt/dev/Slovo/public",
    "/home/berov/perl5/perlbrew/perls/perl-5.28.2/lib/site_perl/5.28.2/Mojolicious/Plugin/Minion/resources/public",
    "/home/berov/opt/dev/Slovo/lib/Slovo/resources/public"
  ]

In addition the current domain row from table C<domove> becomes available in
the stash as C<$domain>.

  # In a controller or model
  $c->stash('domain')->{id};
  $m->c->stash('domain')->{aliases};

  # In a template like
  # lib/Slovo/resources/templates/stranici/_form.html.ep
  <%=
  select_box
    dom_id   => $domove,
    required => 1,
    label    => 'Дом',
    title    => 'В кой сайт се намира страницата.',
    readonly => '',
    value    => $domain->{id} #default value
  %>

=head2 before_dispatch

On each request we check if we have a logged in user and set the current user
to C<guest> if we don't. This way every part of the application (including
newly developed plugins) can count on having a current user. The user is needed
to determine the permissions for any table that has column C<permissions>. The
current user is available as C<$c-E<gt>user>.

=head1 HELPERS

Slovo implements the following helpers.

=head2 openapi_spec

We need to have our OpenAPI API specification always at hand as a unified
source of truth so here it is.

    # anywhere via $app or $c, even not via a REST call
    state $columns =
        $c->openapi_spec('/paths/~1stranici/get/parameters/3/default');
    [
      "id",
      "pid",
      "alias",
      "title",
      "is_dir"
    ]

=head1 BUGS, SUPPORT, CONTRIBUTING, DISCUSS

=for html <a href="https://travis-ci.org/kberov/Slovo"><img src="https://travis-ci.org/kberov/Slovo.svg?branch=master"></a>

To report a bug, please create issues at
L<GitHub|https://github.com/kberov/Slovo/issues>, fork the project and make
pull requests.


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

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

The full text of the license can be found in the
LICENSE file included with this module.

This distribution contains other free software which belongs to their
respective authors.

=head1 TODO

=over

=item * Stop adding features. Stabilize what we have.

=item * Gradually replace L<MUI CSS|https://www.muicss.com/> with L<Chota
CSS|https://jenil.github.io/chota/> - site part is done.

=item * Considerably improve the Adminiastration UI - now it is quite
simplistic. Use ES6 directly as per L<browsers compatibility
table|https://kangax.github.io/compat-table/es6/>

=item * Consider using L<Mithril|https://github.com/MithrilJS/mithril.js> or
L<Vue.js|https://vuejs.org/> or something light as frontend framework for
building UI. We already use jQuery distributed with the Mojolicious distro.

=back

=head1 SEE ALSO

L<Slovo::Plugin::TagHelpers>, L<Slovo::Plugin::DefaultHelpers>,
L<Slovo::Validator>, L<Mojolicious>, L<Mojolicious::Guides>

=cut

