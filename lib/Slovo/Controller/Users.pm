package Slovo::Controller::Users;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

# GET /users/create
# Display form for creating resource in table users.
sub create($c) {
  return $c->render(users => {}, user => $c->user);
}

# POST /users
# Add a new record to table users.
sub store($c) {
  my $users = $c->users;
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $users->add($in);
    $c->res->headers->location(
                           $c->url_for("api.show_users", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;

  #TODO: FIX: implement proper validation error handling
  return $c->render(action => 'create', users => {}) if $v->has_error;
  my $in = $v->output;
  $in->{created_by} = $in->{changed_by} = $c->user->{id};
  $in->{reg_time}   = time - 1;
  $in->{start_date} //= time - 1;
  $in->{disabled}   //= 0;
  $in->{stop_date} = 0;

  # 1.1 Check if user already exists
  my $u = $users->find_where(
                  [{login_name => $in->{login_name}}, {email => $in->{email}}]);
  if ($u) {
    my @data = ();
    if ($u->{login_name} eq $in->{login_name}) {
      push @data, $u->{login_name};
    }
    if ($u->{email} eq $in->{email}) {
      push @data, $u->{email};
    }
    $c->flash(message => 'Потребител със същите данни ('
              . join(', ', @data)
              . ') вече съществува.');
    return $c->redirect_to('create_users');
  }

  # 2. Insert it into the database
  my $id = $users->add($in);

  #3. redirect
  if ($INC{'Slovo/Task/SendOnboardingEmail.pm'}) {

    # send email from the current user to the new user to login for the first
    # time and change his password.
    my $job_id = $c->minion->enqueue(
                        mail_first_login => [
                          {%{$c->user}} => {%{$users->find_where({id => $id})}},
                          $c->req->headers->host
                        ]
    );
    return $c->redirect_to('users_store_result', jid => $job_id);
  }
  return $c->redirect_to('home_users');
}

# GET /users/store_result/:jid
sub store_result ($c) {
  return $c->reply->not_found
    unless my $job = $c->minion->job($c->param('jid'));
  return $c->render(job => $job);
}

# GET /users/:id/edit
# Display form for edititing resource in table users.
sub edit($c) {
  my $row = $c->users->find_where({id => $c->param('id')});
  for (keys %$row) {
    $c->req->param($_ => $row->{$_});    # prefill form fields.
  }
  return $c->render(users => $row, user => $c->user);
}

# PUT /users/:id
# Update the record in table users
sub update($c) {

  # Validate input
  my $v  = $c->_validation;
  my $in = $v->output;
  my $id = $c->param('id');
  return $c->render(action => 'edit', users => $in) if $v->has_error;

  # only admins can edit groups
  delete $in->{groups} unless ($c->groups->is_admin($c->user->{id}));

  # Update the record
  $in->{changed_by} = $c->user->{id};
  $in->{tstamp}     = time - 1;
  $c->users->save($id, $in);
  return $c->redirect_to('show_users', id => $id);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  # $c->res->headers->location($c->url_for(show_users => {id => $id}));
  # return $c->render(text => '', status => 204);
}

# GET /users/:id
# Display a record from table users.
sub show($c) {
  my $row = $c->users->find_where({id => $c->param('id')});
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(users => $row);
}

# GET /users
# List resources from table users.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  my $stashkey = 'users';
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    $stashkey = 'openapi';
  }

  my $users = $c->users->all({where => {disabled => {-in => [0, 1]}}});
  return $c->render($stashkey => $users, user => $c->user);
}

# DELETE /users/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->users->find($input->{id});
    $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      && return
      unless $row;
    $c->users->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->users->remove($c->param('id'));
  return $c->redirect_to('home_users');
}


# Validation for actions that store or update
sub _validation($c) {
  my $v       = $c->validation;
  my $mail_rx = qr/^[\w\-\+\.]{1,154}\@[\w\-\+\.]{1,100}$/x;

  # Add validation rules for the record to be stored in the database
  $v->optional('group_id',   'trim')->like(qr/^\d+$/);
  $v->optional('login_name', 'trim')->like(qr/^[\p{IsAlnum}\.\-\$]{4,12}$/x);
  if ($c->stash->{action} eq 'store') {
    $v->required('login_password', 'trim')->like(qr/^[A-F0-9]{40}$/i);
    $v->required('first_name',     'trim')->size(2, 100);
    $v->required('last_name',      'trim')->size(2, 100);
    $v->required('email',          'trim')->like($mail_rx);
  }
  else {
    $v->optional('login_password', 'trim')->like(qr/^[A-F0-9]{40}$/i);
    $v->optional('first_name',     'trim')->size(2, 100);
    $v->optional('last_name',      'trim')->size(2, 100);
    $v->optional('email',          'trim')->like($mail_rx);
    $v->optional('id',             'trim')->like(qr/^\d+$/);
    my $groups
      = $c->groups->all_with_member($c->stash('id'))->map(sub { $_->{id} });
    $v->optional('groups')->in(@$groups);
  }
  $v->optional('description', 'trim')->size(0, 255);

  $v->optional('disabled', 'trim')->like(qr/^[01]$/);
  my $time_qr = qr/^\d{1,10}$/;
  $v->optional('start_date', 'trim')->like($time_qr);
  $v->optional('stop_date',  'trim')->like($time_qr);

  return $v;
}

1;
