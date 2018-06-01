package Slovo::Controller::Auth;
use Mojo::Base 'Slovo::Controller', -signatures;

sub form($c) {

  #TODO: remember where the user is comming from to redirect him back
  #afterwards if the place he is comming from is in the siame domain. If not,
  #redirect him to the main page.
  return $c->render;
}

# Sign in the user.
sub sign_in ($c) {

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
  return $c->render(
                  text => ($c->authenticate($o->{login_name}, $o->{digest}, $o))
                  ? 'ok'
                  : 'failed');

  # TODO: Redirect to the page where user wanted to go or where he was
  # initially
  # return $c->redirect_to('/') unless $v->has_data;
}

sub sign_out ($c) {
  return $c->logout && $c->redirect_to('/');
}

sub under_management($c) {
  my $u = $c->user;
  return 1 if ($u && $u->{login_name} ne 'guest');
  return $c->redirect_to('authform');
}

sub check($c) {
  $c->redirect_to('sign_in') and return 0 unless ($c->is_user_authenticated);
  return 1;
}

sub load_user ($c, $uid) {
  return $c->users->find($uid) // $c->users->find_by_login_name('guest');
}

sub validate_user ($c, $login_name, $clrf_pass, $data) {
  return $c->users->find_by_login_name($login_name)->{id};
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

This is a call back when user tries to acces a page i<under> c</управление>. If
user is authenticated returns true. If not, redirects to L</form>.

=head2 sign_in

Route: C<{post =E<gt> '/входъ', to =E<gt> 'auth#sign_in', name =E<gt> 'sign_in'}>.

Finds and logs in a user locally. On success redirects the user to the page
from which it was redirected to the login page. On failure redirects again to
the login page.

=head2 METHODS

L<Slovo::Controller::Auth> inherits all methods from L<Slovo::Controller> and
implements the following new ones.

=head2 check

Checks if a user is authenticated. If yes, returns true. If not, redirects to
C</входъ> and returns false.

=head1 FUNCTIONS

Slovo::Controller::Auth implements the following functions executed by L<Mojolicious::Plugin::Authentication>.

=head2 load_user

=head2 validate_user


=head1 SEE ALSO

L<Mojolicious::Plugin::Authentication>

=cut

