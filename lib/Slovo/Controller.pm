package Slovo::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

our $DEV_MODE = ($ENV{MOJO_MODE} || '' =~ /dev/);

has not_found_id => sub { $_[0]->stranici->not_found_id };
has not_found_code => 404;

has description => 'Slovo is a simple extensible CMS.';
has keywords    => 'SSOT, CRM, ERP, CMS, Perl, Mojolicious, SQL';

sub generator { return 'Slovo ' . $Slovo::VERSION . ' - ' . $Slovo::CODENAME }

has domain => sub {
  my $domain = $_[0]->req->headers->host;
  $domain =~ s/(\:\d+)$//;    # remove port
  return $domain;
};

sub debug;
if ($DEV_MODE) {

  sub debug {
    my ($c, @params) = @_;

    # https://stackoverflow.com/questions/50489062
    # Display readable UTF-8
    # Redefine Data::Dumper::qquote() to do nothing
    ##no critic qw(TestingAndDebugging::ProhibitNoWarnings)
    no warnings 'redefine';
    local *Data::Dumper::qquote = sub {qq["${\(shift)}"]};
    local $Data::Dumper::Useperl = 1;
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
