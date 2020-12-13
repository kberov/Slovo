package Slovo::Command::Author::generate::a2htaccess;
use Mojo::Base 'Slovo::Command', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::File 'path';
use Mojo::Util 'getopt';

has description => 'Generate a .htaccess file for running Slovo under Apache 2/CGI';
has usage       => sub { shift->extract_usage };
my $exiting    = ' Exiting without doing anything further.';
my $continuing = ' Continuing...';

sub run ($self, @args) {

  #TODO: Add option for common aliases to be taken into account when writing
  getopt \@args,

    'r|docroot=s'    => \(my $docroot    = ''),
    's|cgi_script=s' => \(my $cgi_script = ''),
    ;
  $self->quiet(0);
  my $app  = $self->app;
  my $home = $app->home;
  unless ($docroot) {
    $docroot = $home->dirname;
    say 'Assuming DocumentRoot: ' . $docroot . $continuing;
  }
  else {
    $docroot = path($docroot);
  }
  unless (-d $docroot) {
    say 'There is no such DocumentRoot: ' . $docroot . $exiting;
    return;
  }

  my $cgi_file;
  unless ($cgi_script) {
    $cgi_script = $app->moniker . '\.cgi';
    $cgi_file
      = $home->list_tree({max_depth => 1})->first(qr/$cgi_script$/) || $cgi_script;
    say 'Assuming CGI script: ' . $cgi_file . $continuing;
  }
  else { $cgi_file = $cgi_script; }
  unless (-f $cgi_file) {
    say 'There is no such CGI script: '
      . $cgi_file
      . '. Please run command `'
      . $0
      . ' generate cgi_script` first. '
      . $exiting;
    return;
  }
  my $htaccess = path($docroot)->child('.htaccess');
  $self->render_to_file('a2htaccess', $htaccess,
    {app => $app, moniker => $app->moniker, cgi_script => $cgi_file =~ s|.+/||gr});
  $self->chmod_file($htaccess, oct(644));
  return;
}

1;

=encoding utf8

=head1 NAME

Slovo::Command::Author::generate::a2htaccess - Generate a .htaccess for running
Slovo under Apache 2/CGI

=head1 SYNOPSIS

    Usage: slovo [OPTIONS]
    # Default values.
    slovo generate a2htaccess
    # Custom values
    slovo generate a2htaccess -r /home/me/www --cgi_script index.cgi

  Options:
    -h, --help       Show this summary of available options
    -r, --docroot    Defaults to $app->home/..
    -s, --cgi_script Defaults to $app->moniker.cgi


=head1 DESCRIPTION

This command expects that you have already run
L<Slovo::Command::Author::generate::a2htaccess>.

L<Slovo::Command::Author::generate::a2htaccess> will generate a .htaccess for
running Slovo under Apache/CGI. Although Slovo performs best as a daemon run by
hypnotoad, it can as well be used on a cheap shared hosting. The .htaccess adds
settings for Apache2 to preprocess all requests via mod_rewrite. When the
produced CGI script (e.g. C<slovo.cgi>) is run on a page from the site, it will
dump the produced on-the-fly HTML to a static html-file. Later, upon another
HTTP request, the produced html-file will be just spit out by Apache without
invoking slovo.cgi again. This way Slovo acts as a static site generator. This
is completely enough for blogs. Serving static pages is faster than anything
else.

=head1 ATTRIBUTES

L<Slovo::Command::Author::generate::a2htaccess> inherits all attributes from
L<Slovo::Command> and implements the following new ones.

=head2 description

  my $description = $a2htaccess->description;
  $cpanify        = $a2htaccess->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $a2htaccess->usage;
  $cpanify  = $a2htaccess->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Slovo::Command::Author::generate::a2htaccess> inherits all methods from
L<Slovo::Command> and implements the following new ones.

=head2 run

  $a2htaccess->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Slovo>,L<Mojolicious::Command>
L<Mojolicious::Guides::Cookbook/Adding-commands-to-Mojolicious>,
L<Mojolicious::Guides>, L<https://слово.бг>.

=cut

__DATA__

@@ a2htaccess

# Apache 2 .htaccess configuration for Slovo.
# Generated by Slovo::Command::Author::generate::a2htaccess using <%= __FILE__ %>.
# Note!! If you run again `slovo generate a2htaccess` this file will NOT be
# rewritten. Note! Not sure if the produced .htaccess will work fine for you so
# make sure to test locally first.


# Uncomment the SetEnv line when going live OR regenerate slovo.cgi like this:
# slovo generate cgi_script -f slovo.cgi -m production
# SetEnv HTTP_MOJO_MODE production

# use utf-8 encoding for anything served text/plain or text/html
AddDefaultCharset utf-8

# Protect files and directories from prying eyes.
<FilesMatch "(templ/|etc/|lib/|log/|t/|_build/|cover_db/|\.(pmc?|ep|conf|log|t|bak|yml|sqlite|sql)|READM.+|MANIF.+|Build.PL|Build|Makefi.+)$">
    #2.2 configuration:
    <IfModule !mod_authz_core.c>
      Order deny,allow
      Deny from all
    </IfModule>
    #2.4 configuration:
    <IfModule mod_authz_core.c>
      Require all denied
    </IfModule>
</FilesMatch>
Options -Indexes +FollowSymLinks +ExecCGI

# Requires mod_expires to be enabled.
<IfModule mod_expires.c>
  # Enable expirations.
  ExpiresActive On

  ExpiresDefault "access plus 1 month"
  <IfModule mod_headers.c>
    Header append Cache-Control "public"
  </IfModule>
  <FilesMatch <%=$cgi_script%>>
    # Do not allow slovo responses to be cached unless they explicitly send
    # cache headers themselves.
    ExpiresActive Off
  </FilesMatch>
</IfModule>

<Files ~ "^(<%=$cgi_script%>)$">
    SetHandler  cgi-script
</Files>


# Some more security. Redefine the mime type for the most common types of scripts
AddType text/plain .shtml .php .php3 .phtml .phtm .pl .py

# Make Slovo serve as DirectoryIndex and handle any 404 errors.
DirectoryIndex /<%=$moniker%>/<%=$cgi_script%>
ErrorDocument 404 /<%=$moniker%>/<%=$cgi_script%>/%{REQUEST_URI}

<IfModule mod_rewrite.c>
  RewriteEngine on
  RewriteBase /

  # Do not apply rules when requesting "favicon.ico"
  RewriteCond %{REQUEST_FILENAME} favicon.ico [NC]
  RewriteRule .* - [END]

  # Do not apply rules when requesting "<%=$cgi_script%>"
  RewriteCond %{SCRIPT_NAME} /<%=$moniker%>/<%=$cgi_script%> [NC]
  RewriteRule .* - [NE,END]

  # Redirect all requests for Slovo static files to respective domain's public/ directory.
  # /css/fonts.css becomes /domove/t.com/public/css/fonts.css
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  # Match example.com out of ((www|dev|qa).)?example.com
  RewriteCond %{HTTP_HOST} ([\w\-]+.[\w\-]+)$
  RewriteCond %{DOCUMENT_ROOT}/<%=$moniker%>/domove/%1/public/$1 -f
  RewriteRule ^((?:css|img|js|fonts)/.+)$  /<%=$moniker%>/domove/%1/public/$1 [NE,END]

  # example.com/about-en-us.html becomes example.com/domove/t.com/public/cached/about-en-us.html
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteCond %{HTTP_HOST} ([\w\-]+.[\w\-]+)$
  RewriteCond %{DOCUMENT_ROOT}/<%=$moniker%>/domove/%1/public/cached/$1 -f
  RewriteRule ^(.+(?!\.cgi).+\.html)$  /<%=$moniker%>/domove/%1/public/cached/$1 [NE,END]

<% if ($app->mode =~/^prod/) { %>
  # ONLY on production: To redirect all users to access the site WITHOUT the
  # '(www|qa|dev).' prefix and switch ON SSL (http://www.example.com/... will
  # be redirected to http://example.com/...) uncomment the following:
  # RewriteCond %{HTTP_HOST} ^(.+)$ [NC]
  # RewriteRule ^ http%{ENV:protossl}://%1%{REQUEST_URI} [NE,L,R=301]
<% } %>

  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule ^((?!\.cgi).+(?!\.html))$  /<%=$moniker%>/<%=$cgi_script%>/$1 [QSA,NE,END]
</IfModule>

