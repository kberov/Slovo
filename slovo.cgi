#!/home/berov/perl5/perlbrew/perls/perl-5.36.0/bin/perl
use strict;
use warnings;
use lib ();

BEGIN {
  $ENV{MOJO_MODE} = $ENV{HTTP_MOJO_MODE} || 'development';
  $ENV{MOJO_HOME} = $ENV{HTTP_MOJO_HOME} || '/home/berov/opt/dev/Slovo';
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
