package Slovo::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

our $DEV_MODE = ($ENV{MOJO_MODE} || '' =~ /dev/);

has description => 'Slovo is a simple extensible CMS.';
has keywords    => 'SSOT, CRM, ERP, CMS, Perl, Mojolicious, SQL';

sub generator { return 'Slovo ' . $Slovo::VERSION . ' - ' . $Slovo::CODENAME }

sub debug;
if ($DEV_MODE) {

  sub debug {
    my ($c, @params) = @_;
    my ($package, $filename, $line, $subroutine) = caller(0);
    state $log = $c->app->log;
    for my $pp (@params) {
      $log->debug(ref $pp ? $c->dumper($pp) : $pp,
                  ($pp eq $params[-1] ? "    at $filename:$line" : ''));
    }
    return;
  }
}


1;
