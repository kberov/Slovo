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
  $v->required('login_name', 'trim')->like(qr/^[\p{IsAlnum}\.\-\$]{3,12}$/x);
  $v->required('digest')->like(qr/[0-9a-f]{40}/i);

  if ($v->csrf_protect->has_error('csrf_token')) {
    return $c->render(
      sign_in_error => 'Bad CSRF token!',
      status        => 401,
      template      => 'auth/form'
    );
  }
  elsif ($v->has_error) {
    return $c->render(
      sign_in_error => 'И двете полета са задължителни!..',
      status        => 401,
      template      => 'auth/form'
    );
  }

  my $o = $v->output;

  # TODO: Redirect to the page where user wanted to go or where he was before
  if ($c->authenticate($o->{login_name}, $o->{digest}, $o)) {
    my $route
      = ($c->stash('passw_login')
      ? {'edit_users' => {id => $c->user->{id}}}
      : 'home_upravlenie');
    return $c->redirect_to(ref($route) ? %$route : $route);
  }
  $c->stash(sign_in_error => 'Няма такъв потребител или ключът ви е грешен.');
  return $c->render('auth/form');
}

# GET /изходъ
sub sign_out ($c) {
  my $login_name = $c->user->{login_name};
  $c->logout;
  $c->app->log->info('$user ' . $login_name . ' logged out!');
  return $c->redirect_to('authform');
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

  # only admins and users with id=created_by can change another's user account
  my ($e_uid) = $path =~ m|/users/(\d+)|;    #Id of the user being edited
  my $e_user = $e_uid ? $c->users->find_where({id => $e_uid}) : undef;
  if ( $route =~ /^(show|edit|update|remove)_users$/x
    && $e_user
    && ($e_user->{created_by} != $uid && $e_user->{id} != $uid))
  {
    $c->flash(
      message => 'Само управителите на сметки могат да ' . 'променят чужда сметка.');
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

# Used in $c->authenticate by Mojolicious::Plugin::Authentication
# returns the user id or nothing.
sub validate_user ($c, $login_name, $csrf_digest, $dat) {
  state $app = $c->app;
  state $log = $app->log;
  my $u = $c->users->find_by_login_name($login_name);
  if (!$u) {
    $log->error("Error signing in user [$login_name]: "
        . "No such user or user disabled, or stop_date < now!");
    return;
  }
  my $csrf_token = $c->csrf_token;
  my $checksum   = sha1_sum($csrf_token . $u->{login_password});
  unless ($checksum eq $csrf_digest) {

    # try the passw_login
    my $t   = time;
    my $row = $c->dbx->db->select(
      passw_login => 'token',
      {start_date => {'<=' => $t}, to_uid => $u->{id}, stop_date => {'>' => $t}},
      {-desc => ['id']})->hash;
    my $checksum2 = sha1_sum(
      $csrf_token . sha1_sum(encode('UTF-8' => $u->{login_name} . $row->{token})));
    if ($row && ($checksum2 eq $csrf_digest)) {
      $app->dbx->db->delete('passw_login' => {to_uid => $u->{id}});

      # also delete expired but not deleted (for any reason) login tokens.
      $app->dbx->db->delete('passw_login' => {stop_date => {'<=' => $t}});
      $log->info('$user ' . $u->{login_name} . ' logged in using passw_login!');
      $c->flash(message => 'Задайте нов таен ключ!');
      $c->stash(passw_login => 1);
      return $u->{id};
    }
    $log->error("Error signing in user [$u->{login_name}]:"
        . "\$csrf_token:$csrf_token|\$checksum:$checksum \$csrf_digest:$csrf_digest)");
    $log->error('$checksum:sha1_sum($csrf_token . $u->{login_password}) ne $csrf_digest');
    return;
  }
  $log->info('$user ' . $u->{login_name} . ' logged in!');

  return $u->{id};
}

my $msg_expired_token = 'Връзката, която ви доведе тук, е с изтекла годност.' . '';

# GET /първи-входъ/<token:fl_token>
# GET /първи-входъ/32e36608c72bc51c7c39a72fd7e71cba55f3e9ad
sub first_login_form ($c) {
  $c->logout && $c->user($c->users->find_by_login_name('guest'))
    if $c->is_user_authenticated;
  my $token = $c->param('token');
  my $t     = time;
  my $row   = $c->dbx->db->select(
    first_login => '*',
    {start_date => {'<=' => $t}, stop_date => {'>' => $t}, token => $token})->hash;
  unless (defined $row) {
    $c->stash('error_message' => $msg_expired_token);
    $c->app->log->error('Token for first_login_form was not found for user comming from '
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
  my $row   = $c->dbx->db->select(
    first_login => '*',
    {start_date => {'<=' => $t}, stop_date => {'>' => $t}, token => $token})->hash;
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
    $c->stash(error_message => 'Моля, въведете имената на човека,'
        . ' създал вашата сметка, както са изписани в'
        . ' електроннто съобщение с препратката за първо влизане.');
    return $c->render(template => 'auth/first_login_form', row => $row);
  }
  if ($INC{'Slovo/Task/SendOnboardingEmail.pm'}) {
    $app->minion->enqueue(delete_first_login => [$row->{to_uid}, $token]);
  }
  else {
    $app->dbx->db->delete('first_login' => {token => $token, user_id => $row->{to_uid}});

    # also delete expired but not deleted (for any reason) login tokens.
    $app->dbx->db->delete('first_login' => {stop_date => {'<=' => time}});
  }
  $c->users->save($row->{to_uid}, {disabled => 0});
  $c->authenticate(undef, undef, {auto_validate => $row->{to_uid}});
  return $c->redirect_to('edit_users' => {id => $row->{to_uid}});
}

# GET /загубенъ-ключъ
sub lost_password_form ($c) {
  if ($c->req->method eq 'POST') {
    my $v = $c->validation;
    $v->required('email', 'trim')->like(qr/^[\w\-\+\.]{1,154}\@[\w\-\+\.]{1,100}$/x);
    my $in = $v->output;

    if ($INC{'Slovo/Task/SendPasswEmail.pm'}) {

      # send email to the user to login with a temporary password and change his
      # password.
      if (my $user = $c->users->find_where({email => $in->{email}})) {
        my $job_id
          = $c->minion->enqueue(mail_passw_login => [$user, $c->req->headers->host]);
      }
      else {
        $c->app->log->warn('User not found by email to send temporary login password.');
      }
    }
  }
  return $c->render();

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

=head2 first_login_form

Displays a form for confirmation of the names of the user who invited the new
user.

    GET /първи-входъ/<token:fl_token>

C<fl_token> is a route type matching C<qr/[a-f0-9]{40}/>.

=head2 first_login

Compares the entered names of the inviting user with the token and makes other
checks. Signs in the user for the first time.

=head2 form

Route: C<{get =E<gt> '/входъ', to =E<gt> 'auth#form', name =E<gt> 'authform'}>.

Renders a login form. The password is never transmitted in plain text. A digest
is prepared in the browser using JavaScript (see
C<lib/Slovo/resources/templates/auth/form.html.ep>). The digest is sent and
compared on the server side. The digest is different in every POST request.

=head2 lost_password_form

Route:

   {
    any  => '/загубенъ-ключъ',
    to   => 'auth#lost_password_form',
    name => 'lost_password_form'
   },

In case the request is not C<POST> C<$c-E<gt>url_for('lost_password_form')> displays a form
for entering email to which a temporary password to be send. If the request
method is C<POST>, enqueues L<Slovo::Task::SendPasswEmail/mail_passw_login>, if a
user with the given email is found in the database.

=head2 sign_in

Route: C<{post =E<gt> '/входъ', to =E<gt> 'auth#sign_in', name =E<gt> 'sign_in'}>.

Finds and logs in a user locally. On success redirects the user to
L<home_upravlenie|Slovo::Cotroller::Upravlenie/index>. On failure redirects
again to the login page.

=head2 under_management

This is a callback when user tries to access a page I<under> C</Ꙋправленѥ>. If
user is authenticated returns true. If not, returns false and redirects to
L</form>.

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

