package Slovo::Plugin::CGI;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojo::Util qw(punycode_decode);

my $mod_rewrite;

sub register ($self, $app, $config) {

  # Check again if we need this hook at all
  return $self unless $ENV{GATEWAY_INTERFACE};
  $mod_rewrite = $config->{mod_rewrite} //= 1;
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

  # remove /slovo/slovo.cgi from generated links in the page
  if ($mod_rewrite) {
    my $base = $url->base =~ s|$ENV{SCRIPT_NAME}||r;
    $url->base(Mojo::URL->new($base));
  }

  return;
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::CGI - before_dispatch hook under Apache 2/CGI


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

=head1 CONFIGURATION

The folowing option is currently supported.

=head2 mod_rewrite = 1

Boolean. Defaluts to true. Set to 0 to disable removing of C<$ENV{SCRIPT_NAME}>
from C<$c-E<gt>req-E<gt>url-E<gt>base>. This will practically stop removing
C<$ENV{SCRIPT_NAME}> from all generated links. Having C<$ENV{SCRIPT_NAME}> in
URLs also tells mod rewrite to not look for static files in folder domove to
not apply any rules when requestingC<$ENV{SCRIPT_NAME}> 

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

