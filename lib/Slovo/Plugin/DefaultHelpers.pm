package Slovo::Plugin::DefaultHelpers;
use Mojo::Base 'Mojolicious::Plugin::DefaultHelpers', -signatures;

use Mojo::Util qw(punycode_decode);
use Mojo::Collection 'c';

our $DEV_MODE = ($ENV{MOJO_MODE} || '' =~ /dev/);

sub _debug;


sub register ($self, $app, $config) {
  $self->SUPER::register($app) unless exists $app->renderer->helpers->{c};

  # Add our helpers eventually overriding some of the existing ones
  $app->helper(
    host_only => sub {
      lc($_[0]->req->headers->host // 'localhost') =~ s/(\:\d+)$//r;
    });

  $app->helper(
    ihost_only => sub {
      join '.', map { /^xn--(.+)$/ ? punycode_decode $1 : $_ } split /\./,
        $_[0]->host_only;
    });

  # replace is_user_authenticated from M::P::Authentication
  $app->helper(is_user_authenticated =>
      sub { !!($_[0]->user && $_[0]->user->{login_name} ne 'guest') });
  $app->helper(
    languages => sub {
      c(@{$_[0]->openapi_spec('/parameters/language/enum')});
    });
  $app->helper(
    language => sub ($c, $l = '') {
      if ($l) {
        $l = $c->languages->first(qr/^$l$/) // $c->languages->first;
        $c->stash('lang', $l);
        return $c;
      }

      # language param
      $l = $c->stash('lang');

      #existing language
      return $l if ($l = $c->languages->first(qr/^$l$/));

      # default language
      return $c->languages->first;
    });
  $app->helper(debug => \&_debug);
  return $self;
}

if ($DEV_MODE) {

  sub _debug {
    my ($c, @params) = @_;

    # https://stackoverflow.com/questions/50489062
    # Display readable UTF-8
    # Redefine Data::Dumper::qquote() to do nothing
    ##no critic qw(TestingAndDebugging::ProhibitNoWarnings)
    no warnings 'redefine';
    local *Data::Dumper::qquote  = sub {qq["${\(shift)}"]};
    local $Data::Dumper::Useperl = 1;
    my ($package, $filename, $line) = caller(1);
    state $log = $c->app->log;
    my $msg = '';
    for my $p (@params) {

      if (ref $p) {
        $msg .= Mojo::Util::dumper($p);
        chomp $msg if $p eq $params[-1];
      }
      else { $msg .= $p // 'undefined'; }
    }
    $log->debug($msg . "\n at $filename:$line\n in " . (caller(2))[3]);
    return;
  }
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::DefaultHelpers - additional default helpers for Slovo

=head1 SYNOPSIS

    # local.xn--b1arjbl.xn--90ae
    # from http://local.слово.бг:3000
    # or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= host_only %>
    #in a controller
    $c->host_only

    # local.слово.бг
    # from http://local.слово.бг:3000
    # or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= ihost_only %>
    #in a controller
    $c->ihost_only

    <%= language%>

=head1 DESCRIPTION

L<Slovo::Plugin::DefaultHelpers> extends
L<Mojolicious::Plugin::DefaultHelpers>. It provides additional default helpers
for Slovo. They are always loaded and ready for use. DefaultHelpers and
TagHelpers are loaded unconditionally after all other mandatory for Slovo
plugins.

=head1 HELPERS

The following additional helpers are provided.

=head2 host_only

Returns the host_only from C<$c-E<gt>req-E<gt>headers-E<gt>host>.

    # local.xn--b1arjbl.xn--90ae
    # from http://local.слово.бг:3000 or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= host_only %>
    #in a controller
    $c->host_only

=head2 ihost_only

Returns the IDN (Internationalized Domain Name) from the current request.

    # local.слово.бг
    # from http://local.слово.бг:3000 or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= ihost_only %>
    #in a controller
    $c->ihost_only

=head2 is_user_authenticated

We replaced the implementation of this helper, provided otherwise by
L<Mojolicious::Plugin::Authentication/is_user_authenticated>. Now we check if
the user is not C<guest> instead of checking if we have a loaded user all over
the place. This was needed because we wanted to always have a default user. See
L<Slovo/before_dispatch> for details. Now we have default user properties even
if there is not a logged in user. This will be the C<guest> user.

Once again: Now this helper returns true if the current user is not Guest, false
otherwise.

    %# in a template
    Hello <%= $c->user->{first_name} %>,
    % if($c->is_user_authenticated) {
    You can go and <%= link_to manage => url_for('under_management')%> some pages.
    % else {
    You may want to <%=link_to 'sign in' => url_for('sign_in') %>.
    % }

=head2 language

Wrapper for C<$c-E<gt>stash('lang')>, which is set in C<$app-E<gt>defaults> in
C<slovo.conf>. The requested language is also checked if it exists in
C<$c-E<gt>openapi_spec('/parameters/language/enum')>. The first element from
this list is returned if the requested language is not found in it. Using
C<$lang>, found in the stash in templates is strongly discouraged.

    <%= language eq $lang %> <!-- renders 1 -->
    $c->language

=head2 languages

Returns C<$c-E<gt>openapi_spec('/parameters/language/enum')>.

=head1 METHODS

The usual method is implemented.

=head2 register

Calls the parent's register if needed and registers additional helpers in Slovo application.


=head1 SEE ALSO

L<Mojolicious::Plugin::DefaultHelpers> L<Slovo::Plugin::TagHelpers>

=cut

