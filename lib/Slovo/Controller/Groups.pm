package Slovo::Controller::Groups;
use Mojo::Base 'Slovo::Controller', -signatures;


# GET /groups/create
# Display form for creating resource in table groups.
sub create($c) {
  return $c->render(groups => {});
}

# POST /groups
# Add a new record to table groups.
sub store($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $c->groups->add($in);
    $c->res->headers->location(
                          $c->url_for("api.show_groups", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'create', groups => {}) if $validation->has_error;

  # 2. Insert it into the database
  my $id = $c->groups->add($validation->output);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_groups', id => $id);
}

# GET /groups/:id/edit
# Display form for edititing resource in table groups.
sub edit($c) {
  return $c->render(groups => $c->groups->find($c->param('id')));
}

# PUT /groups/:id
# Update the record in table groups
sub update($c) {

  # Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'edit', groups => {}) if $validation->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->groups->save($id, $validation->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_groups', id => $id);
}

# GET /groups/:id
# Display a record from table groups.
sub show($c) {
  my $row = $c->groups->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->groups->find($c->param('id'));
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(groups => $row);
}

# GET /groups
# List resources from table groups.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->groups->all($input));
  }
  return $c->render(groups => $c->groups->all);
}

# DELETE /groups/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->groups->find($input->{id});
    $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      && return
      unless $row;
    $c->groups->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->groups->remove($c->param('id'));
  return $c->redirect_to('home_groups');
}


# Validation for actions that store or update
sub _validation($c) {
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->required('id') if $c->stash->{action} ne 'store';
  $v->required('name',        'trim')->size(0, 100);
  $v->required('description', 'trim')->size(0, 255);
  $v->optional('created_by', 'trim')->like(qr/^\d+$/);
  $v->optional('changed_by', 'trim')->like(qr/^\d+$/);
  $v->required('disabled', 'trim')->like(qr/^\d$/);

  return $v;
}

1;
