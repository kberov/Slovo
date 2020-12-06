package Slovo::Command::Author::generate::cgi_script;
use Mojo::Base 'Slovo::Command', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::File 'path';
use Mojo::Util 'getopt';
use Config;

has description => 'Generate a CGI script for running Slovo under Apache 2/CGI';
has usage       => sub { shift->extract_usage };
has exe         => sub {
  my $app = shift->app;
  -f $app->home->child('bin/' . $app->moniker)
    ? $app->home->child('bin/' . $app->moniker)
    : $app->home->child('script/' . $app->moniker);

};

sub run ($self, @args) {
  getopt \@args,

    'f|filename=s' => \(my $filename = ''),
    'c|cgi_mode=s' => \(my $mode     = '');
  my $app = $self->app;

  unless ($filename) {
    $filename = $app->moniker . '.cgi';
    say 'Assuming script name: ' . $filename;
  }
  unless ($mode) {
    $mode = $app->mode;
    say 'Assuming mode: ' . $mode;
  }
  my $file = $app->home->rel_file($filename)->to_abs;
  $self->render_to_file('cgi_script', $file,
    {app => $app, exe => $self->exe, mode => $mode, perlpath => $Config{perlpath}});
  $self->chmod_file($file, oct(755));
  return;
}

1;


=encoding utf8

=head1 NAME

Slovo::Command::Author::generate::cgi_script - Generate a CGI script for
running Slovo under Apache 2/CGI

=head1 SYNOPSIS

    Usage: slovo [OPTIONS]
    # Default values.
    slovo generate cgi_script
    # Custom values
    slovo generate cgi_script -f slovo.cgi -m production

  Options:
    -h, --help            Show this summary of available options
    -f, --filename <name> Defaults to $app->moniker.cgi
    -c, --cgi_mode <name> Defaults to current $app->mode
    -m, --mode     <name> Operating mode for your application, defaults to the
                          value of MOJO_MODE/PLACK_ENV or "development". Will
                          be used for --cgi_mode.

=head1 DESCRIPTION

After running this command it is expected usually to run also
L<Slovo::Command::Author::generate::a2htaccess> to generate the C<.htaccess>
file for the set of domains which you will be running on this virtual host.

L<Slovo::Command::Author::generate::cgi_scrip> will generate a CGI script for
running Slovo under Apache2/CGI. Although Slovo performs best as a daemon, run
by hypnotoad, it can as well be used on a cheap shared hosting. When the
produced CGI script (e.g. C<slovo.cgi>) is run on a page from the site, it
will dump the produced on-the-fly HTML to a static html-file. Later, upon
another HTTP request, the produced html-file will be just spit out by Apache
without invoking slovo.cgi again. This way Slovo acts as a static site
generator. This is completely enough for bloggers. Serving static pages is
faster than anything else.

=head1 ATTRIBUTES

L<Slovo::Command::Author::generate::cgi_script> inherits all attributes from
L<Slovo::Command> and implements the following new ones.

=head2 description

  my $description = $cgi_script->description;
  $cpanify        = $cgi_script->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $cgi_script->usage;
  $cpanify  = $cgi_script->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Slovo::Command::Author::generate::cgi_script> inherits all methods from
L<Slovo::Command> and implements the following new ones.

=head2 run

  $cgi_script->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Slovo::Command::Author::generate::a2htaccess>,
L<Slovo>,L<Mojolicious::Command>
L<Mojolicious::Guides::Cookbook/Adding-commands-to-Mojolicious>,
L<Mojolicious::Guides>, L<https://слово.бг>.

=cut

__DATA__

@@ cgi_script
#!<%=$perlpath%>
use strict;
use warnings;
use lib ();

BEGIN {
  $ENV{MOJO_MODE} = $ENV{HTTP_MOJO_MODE} || '<%=$mode%>';
  $ENV{MOJO_HOME} = $ENV{HTTP_MOJO_HOME} || '<%=$app->home%>';
  for (
    "$ENV{MOJO_HOME}/local/lib/perl5", "$ENV{MOJO_HOME}/lib/perl5",
    "$ENV{MOJO_HOME}/lib",             "$ENV{MOJO_HOME}/site/lib"
    )
  {
    lib->import($_) if (-d $_);
  }
}

use Mojolicious::Commands;

# Start Slovo as CGI
Mojolicious::Commands->start_app('Slovo', 'cgi');

