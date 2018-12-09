package Slovo::Controller::Auth;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::Util qw(encode sha1_sum);

# Returns the name of the geter for the current user.
# Needed by Mojolicious::Plugin::Authentication.
# See Slovo::_before_dispatch to understand how this function name is used.
sub current_user_fn { return 'user' }

# Display the form for signing in.
# GET /входъ
sub form($c) {

  #TODO: remember where the user is comming from to redirect him back
  #afterwards if the place he is comming from in the siame domain. If not,
  #redirect him to the main page.
  $c->is_user_authenticated && return $c->redirect_to('/');
  return $c->render;
}

# Sign in the user.
# POST /входъ
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

# GET /изходъ
sub sign_out ($c) {
  return $c->logout && $c->redirect_to('/');
}

sub under_management($c) {
  unless ($c->is_user_authenticated) {
    $c->redirect_to('authform');
    return 0;
  }

  my $uid   = $c->user->{id};
  my $path  = $c->req->url->path->to_string;
  my $route = $c->current_route;

  return 1 if $c->groups->is_admin($uid);

  # for now only admins can manage groups and domains
  if ($route =~ /groups|domove$/) {
    $c->flash(message => 'Само управителите се грижат'
              . ' за множествата от потребители и домейните.');
    $c->redirect_to('home_upravlenie');
    return 0;
  }

  # only admins can change another's user account
  if ($route =~ /^(show|edit|update|remove)_users$/x && $path !~ m|/$uid|) {
    $c->flash(
           message => 'Само управителите могат да ' . 'променят чужда сметка.');
    $c->redirect_to('home_upravlenie');
    return 0;
  }
  return 1;
}

# secure route /Ꙋправленѥ/minion.
# Allow access to only authenticated members of the admin group.
sub under_minion($c) {

  # TODO: make the group configurable
  unless ($c->groups->is_admin($c->user->{id})) {
    $c->flash(message => 'Само управителите могат да управляват задачите.');
    $c->redirect_to('home_upravlenie');
    return 0;
  }
  return 1;
}

sub load_user ($c, $uid) {

  # TODO: implement some smarter caching (at least use Mojo::Cache).
  # state $users ={};
  # keys %$users >2000 && $users = {};#reset cached users.
  # return $users->{$uid}//=$c->users->find($uid);
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

my $msg_expired_token = 'Връзката, която ви доведе тук, е с изтекла годност. ';

# TODO:  . 'Помолете да ви изпратят нова.';
# GET /първи-входъ/<token:fl_token>
# GET /първи-входъ/32e36608c72bc51c7c39a72fd7e71cba55f3e9ad
sub first_login_form ($c) {
  $c->logout && $c->user($c->users->find_by_login_name('guest'))
    if $c->is_user_authenticated;
  my $token = $c->param('token');
  my $t     = time;
  my $row = $c->dbx->db->select(
         first_login => '*',
         {start_date => {'<=' => $t}, stop_date => {'>' => $t}, token => $token}
  )->hash;
  unless (defined $row) {
    $c->stash('error_message' => $msg_expired_token);
    $c->app->log->error(
               'Token for first_login_form was not found for user comming from '
                 . ($c->req->headers->referrer || 'nowhere')
                 . '.');
  }
  return $c->render(row => $row);
}

# POST /първи-входъ
sub first_login($c) {
  state $app = $c->app;
  my $token = $c->param('token');
  my $t     = time;
  my $row = $c->dbx->db->select(
         first_login => '*',
         {start_date => {'<=' => $t}, stop_date => {'>' => $t}, token => $token}
  )->hash;
  unless (defined $row) {
    $c->stash(error_message => $msg_expired_token);
    return $c->render('auth/first_login_form');

  }
  my $v = $c->validation;
  $v->required('first_name', 'trim')->required('last_name', 'trim');
  my $in = $v->output;
  my $ok = (
            sha1_sum(
                         $row->{start_date}
                       . encode('UTF-8' => $in->{first_name} . $in->{last_name})
                       . $row->{from_uid}
                       . $row->{to_uid}
              ) eq $token
           );
  unless ($ok) {
    $c->stash(  error_message => 'Моля, въведете имената на човека,'
              . ' създал вашата сметка, както са изписани в'
              . ' електроннто съобщение с препратката за първо влизане.');
    return $c->render(template => 'auth/first_login_form', row => $row);
  }
  if ($INC{'Slovo/Task/SendOnboardingEmail.pm'}) {
    $app->minion->enqueue(delete_first_login => [$row->{to_uid}, $token]);
  }
  else {
    $app->dbx->db->delete(
                 'first_login' => {token => $token, user_id => $row->{to_uid}});

    # also delete expired but not deleted (for any reason) login tokens.
    $app->dbx->db->delete('first_login' => {stop_date => {'<=' => time}});
  }
  $c->users->save($row->{to_uid}, {disabled => 0});
  $c->authenticate(undef, undef, {auto_validate => $row->{to_uid}});
  return $c->redirect_to('edit_users' => {id => $row->{to_uid}});
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

This is a callback when user tries to access a page I<under> C</Ꙋправленѥ>. If
user is authenticated returns true. If not, returns false and redirects to
L</form>.

=head2 sign_in

Route: C<{post =E<gt> '/входъ', to =E<gt> 'auth#sign_in', name =E<gt> 'sign_in'}>.

Finds and logs in a user locally. On success redirects the user to the page
from which it was redirected to the login page. On failure redirects again to
the login page.

=head2 first_login_form

Displays a form for confirmation of the names of the user who invited the new
user.

    GET /първи-входъ/<token:fl_token>

C<fl_token> is a route type matching C<qr/[a-f0-9]{40}/>.

=head2 first_login

Compares the entered names of the inviting user with the token and makes other
checks. Signs in the user for the first time.

=head2 under_minion


Allow access to only authenticated members of the admin group. All routes
generated by L<Minion::Admin> are under this route. 

    GET /Ꙋправленѥ/minion


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

L<Mojolicious::Plugin::Authentication>,
L<Slovo::Task::SendOnboardingEmail>

=cut

