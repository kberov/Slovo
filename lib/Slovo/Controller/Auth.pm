package Slovo::Controller::Auth;
use Mojo::Base 'Slovo::Controller', -signatures;
use Mojo::Util qw(sha1_sum);

# Returns the name of the getter for the current user.
# Needed by Mojolicious::Plugin::Authentication.
# See Slovo::_before_dispatch to understand how this function name is used.
sub current_user_fn { return 'user' }

sub form($c) {

  #TODO: remember where the user is comming from to redirect him back
  #afterwards if the place he is comming from in the siame domain. If not,
  #redirect him to the main page.
  $c->is_user_authenticated && return $c->redirect_to('/');
  return $c->render;
}

# Sign in the user.
sub sign_in($c) {

  #1. do basic validation first
  my $v = $c->validation;
  $v->required('login_name', 'trim')->size(5, 100);
  $v->required('digest')->like(qr/[0-9a-f]{40}/i);

  if ($v->csrf_protect->has_error('csrf_token')) {

    return
      $c->render(
                 error_login => 'Bad CSRF token!',
                 status      => 401,
                 template    => 'auth/form'
                );
  }
  elsif ($v->has_error) {
    return
      $c->render(
                 error_login => 'Could not login!...',
                 status      => 401,
                 template    => 'auth/form'
                );
  }

  my $o = $v->output;

  # TODO: Redirect to the page where user wanted to go or where he was before
  # TODO: No need to redirect if login is unsuccessful. Just render auth/form
  # and display an error message. "Forgotten password?"
  return $c->authenticate($o->{login_name}, $o->{digest}, $o)
    ? $c->redirect_to('/')
    : $c->redirect_to('authform');
}

sub sign_out ($c) {
  return $c->logout && $c->redirect_to('/');
}

sub under_management($c) {
  return 1 if ($c->is_user_authenticated);
  $c->redirect_to('authform');
  return 0;
}

sub load_user ($c, $uid) {
  return $c->users->find($uid);
}

sub validate_user ($c, $login_name, $csrf_digest, $dat) {
  my $u = $c->users->find_by_login_name($login_name);
  if (!$u) { delete $c->session->{csrf_token} && return; }

  my $checksum = sha1_sum($c->csrf_token . $u->{login_password});
  return unless ($checksum eq $csrf_digest);
  $c->app->log->info('$user ' . $u->{login_name} . ' logged in!');
  delete $c->session->{csrf_token};

  return $u->{id};
}


1;

=encoding utf8

=head1 NAME

Slovo::Controller::Auth - и миръ Его не позна.

=head1 DESCRIPTION

L<Slovo::Controller::Auth> implements actions for authenticating users. It
depends on functionality, provided by L<Mojolicious::Plugin::Authentication>.
All the routes' paths mentioned below are easily modifiable because they are
described in C<lib/Slovo/resources/etc/routes.conf> thanks to
L<Mojolicious::Plugin::RoutesConfig>.

=head1 ACTIONS

Mojolicious::Plugin::Authentication implements the following actions.

=head2 form

Route: C<{get =E<gt> '/входъ', to =E<gt> 'auth#form', name =E<gt> 'authform'}>.

Renders a login form. The password is never transmitted in plain text. A digest
is prepared in the browser using JavaScript (see
C<lib/Slovo/resources/templates/auth/form.html.ep>). The digest is sent and
compared on the server side. The digest is different in every POST request.

=head2 under_management

This is a callback when user tries to acces a page I<under> C</управление>. If
user is authenticated returns true. If not, returns false and redirects to
L</form>.

=head2 sign_in

Route: C<{post =E<gt> '/входъ', to =E<gt> 'auth#sign_in', name =E<gt> 'sign_in'}>.

Finds and logs in a user locally. On success redirects the user to the page
from which it was redirected to the login page. On failure redirects again to
the login page.

=head2 METHODS

L<Slovo::Controller::Auth> inherits all methods from L<Slovo::Controller> and
implements the following new ones.

=head1 FUNCTIONS

Slovo::Controller::Auth implements the following functions executed or used by
L<Mojolicious::Plugin::Authentication>.

=head2 current_user_fn

Returns the name of the helper used for getting the properties of the current
user. The name is C<user>. It is passed in configuration to
L<Mojolicious::Plugin::Authentication> to generate the helper with this name.
This value must not be changed. Otherwise you will get runtime errors all over
the place because C<$c-E<gt>user> is used a lot.

=head2 load_user

This function is passed to L<Mojolicious::Plugin::Authentication> as reference.
See L<Mojolicious::Plugin::Authentication/USER-LOADING>.


=head2 validate_user

This function is passed to L<Mojolicious::Plugin::Authentication> as reference.
See L<Mojolicious::Plugin::Authentication/USER-VALIDATION>.


=head1 SEE ALSO

L<Mojolicious::Plugin::Authentication>

=cut

