package Slovo::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

our $DEV_MODE = ($ENV{MOJO_MODE} || '' =~ /dev/);

has description => 'Slovo is a simple extensible CMS.';
has keywords    => 'SSOT, CRM, ERP, CMS, Perl, Mojolicious, SQL';

sub generator { return 'Slovo ' . $Slovo::VERSION . ' - ' . $Slovo::CODENAME }

sub config {
  state $app = $_[0]->app;
  return $app->config(ref $_[0])->{$_[1]} if $_[1];    #if key
  return $app->config(ref $_[0]);
}

sub debug;
if ($DEV_MODE) {

  sub debug {
    my ($package, $filename, $line, $subroutine) = caller(0);
    state $log = $_[0]->app->log;
    return $log->debug(@_[1 .. $#_], "    at $filename:$line");
  }
}


1;
