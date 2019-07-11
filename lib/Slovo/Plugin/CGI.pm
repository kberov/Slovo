package Slovo::Plugin::CGI;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::Util qw(punycode_decode);

sub register ($self, $app, $config) {

  # Check again if we need this hook at all
  return $self unless $ENV{GATEWAY_INTERFACE};
  $app->hook(before_dispatch => \&_handle_cgi);
  return $self;
}

sub _handle_cgi ($c) {
  my $url  = $c->req->url;
  my $path = $url->path->to_string || '/';
  $path =~ s|^.+cached/?||;
  if ($path =~ m'%') {
    $path = Mojo::Util::url_unescape $path;
    $path = Mojo::Util::decode 'UTF-8', $path;
  }

  # no path merging
  $url->path($path =~ m'^/' ? $path : "/$path");

  # no /slovo/slovo.cgi in generated links in the page
  if ($ENV{REWRITE_ENGINE_ON}) {
    my $base = $url->base =~ s|$ENV{SCRIPT_NAME}||r;
    $url->base(Mojo::URL->new($base));
  }

  return;
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::CGI - before_dispatch hook under Apache/CGI


=head1 DESCRIPTION

L<Slovo::Plugin::CGI> extends L<Mojolicious::Plugin>. It provides a
L</before_dispatch> hook to handle Apache double encoding of the current url
and to strip the C<$ENV{SCRIPT_NAME}> from produced by Slovo urls. This plugin
is enabled by default and will detect if the app is run under CGI. If app is
run as a daemon this plugin will do nothing.

=head1 HOOKS


=head2 before_dispatch

Handles Apache double encoding of the UTf-8 url and strips
the C<$ENV{SCRIPT_NAME}> from produced by Slovo urls.


=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    berov на cpan точка org
    http://i-can.eu

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

