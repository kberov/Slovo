package Slovo::Plugin::DefaultHelpers;
use Mojo::Base 'Mojolicious::Plugin::DefaultHelpers', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::Util qw(punycode_decode);


sub register ($self, $app, $config) {
  $self->SUPER::register($app) unless exists $app->renderer->helpers->{c};

  # Add our helpers eventually overriding some of the existing ones
  $app->helper(
    domain => sub {
      lc $_[0]->req->headers->host =~ s/(\:\d+)$//r;
    }
  );

  $app->helper(
    idomain => sub {
      join '.', map { /^xn--(.+)$/ ? punycode_decode $1 : $_ } split /\./,
        $_[0]->domain;
    }
  );

  # replace is_user_authenticated from M::P::Authentication
  $app->helper(
         is_user_authenticated => sub { $_[0]->user->{login_name} ne 'guest' });

  # TODO: Implement Slovo::L10N which will provide this helper.
  $app->helper(language => sub { $_[0]->config('default_language') });

  return $self;
}


1;

=encoding utf8

=head1 NAME

Slovo::Plugin::DefaultHelpers – additional default helpers for Slovo

=head1 SYNOPSIS

    # local.xn--b1arjbl.xn--90ae
    # from http://local.слово.бг:3000
    # or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= domain %>
    #in a controller
    $c->domain

    # local.слово.бг
    # from http://local.слово.бг:3000
    # or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= idomain %>
    #in a controller
    $c->idomain

    <%= language%>

=head1 DESCRIPTION

L<Slovo::Plugin::DefaultHelpers> extends
L<Mojolicious::Plugin::DefaultHelpers>. It provides additional default helpers
for Slovo. They are always loaded and ready for use. DefaultHelpers and
TagHelpers are loaded unconditionally after all other mandatory for Slovo
plugins.

=head1 HELPERS

The following additional helpers are provided.

=head2 domain

Returns the domain name from C<$c-E<gt>req-E<gt>headers-E<gt>host>.

    # local.xn--b1arjbl.xn--90ae
    # from http://local.слово.бг:3000 or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= domain %>
    #in a controller
    $c->domain

=head2 idomain

Returns the IDN (Internationalized Domain Name) from the current request.

    # local.слово.бг
    # from http://local.слово.бг:3000 or http://local.xn--b1arjbl.xn--90ae:3000
    # in a template:
    <%= idomain %>
    #in a controller
    $c->idomain

=head2 is_user_authenticated

We replaced the implementation of this helper, provided otherwise by
L<Mojolicious::Plugin::Authentication/is_user_authenticated>. Now we check if
the user is not C<guest> instead of checking if we have a loaded user all over
the place. This was needed because we wanted to always have a default user. See
L</before_dispatch>. Now we have default user properties even if there is not
a logged in user. This will be the C<guest> user.

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

Returns the current language from the request. For now we only return
C<$c-E<gt>config('default_language')> - 'bg-bg'. The extraction f the language
from the current request is to be implemented

    <%= language %>
    $c->language

=head1 METHODS

The usual method is implemented.

=head2 register

Calls the parent's register if needed and registers additional helpers in Slovo application.


=head1 SEE ALSO

L<Mojolicious::Plugin::DefaultHelpers> L<Slovo::Plugin::TagHelpers>

=cut

