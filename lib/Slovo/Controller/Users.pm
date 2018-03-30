package Slovo::Controller::Users;
use Mojo::Base 'Slovo::Controller', -signatures;


# GET /users/create
# Display form for creating resource in table users.
sub create($c) {
  return $c->render(users => {});
}

# POST /users
# Add a new record to table users.
sub store($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $c->users->add($in);
    $c->res->headers->location(
                           $c->url_for("api.show_users", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'create', users => {}) if $validation->has_error;

  # 2. Insert it into the database
  my $id = $c->users->add($validation->output);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_users', id => $id);
}

# GET /users/:id/edit
# Display form for edititing resource in table users.
sub edit($c) {
  return $c->render(users => $c->users->find($c->param('id')));
}

# PUT /users/:id
# Update the record in table users
sub update($c) {

  # Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'edit', users => {}) if $validation->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->users->save($id, $validation->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_users', id => $id);
}

# GET /users/:id
# Display a record from table users.
sub show($c) {
  my $row = $c->users->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->users->find($c->param('id'));
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(users => $row);
}

# GET /users
# List resources from table users.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->users->all($input));
  }
  return $c->render(users => $c->users->all);
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
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->required('id') if $c->stash->{action} ne 'store';
  $v->optional('group_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('login_name', 'trim')->size(0, 100);
  $v->required('login_password', 'trim')->size(0, 40);
  $v->required('first_name',     'trim')->size(0, 100);
  $v->required('last_name',      'trim')->size(0, 100);
  $v->required('email',          'trim')->size(0, 255);
  $v->optional('description', 'trim')->size(0, 255);
  $v->optional('created_by',  'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('changed_by',  'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('tstamp',     'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('reg_time',   'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('disabled',   'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('start_date', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('stop_date',  'trim')->like(qr/\d+(\.\d+)?/);

  return $v;
}

1;
