package Slovo::Controller::Domove;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";


# GET /domove/create
# Display form for creating resource in table domove.
sub create($c) {
  return $c->render(domove => {});
}

# POST /domove
# Add a new record to table domove.
sub store($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $c->domove->add($in);
    $c->res->headers->location(
                          $c->url_for("api.show_domove", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'create', domove => {}) if $validation->has_error;

  # 2. Insert it into the database
  my $id = $c->domove->add($validation->output);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_domove', id => $id);
}

# GET /domove/:id/edit
# Display form for edititing resource in table domove.
sub edit($c) {
  return $c->render(domove => $c->domove->find($c->param('id')));
}

# PUT /domove/:id
# Update the record in table domove
sub update($c) {

  # Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'edit', domove => {}) if $validation->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->domove->save($id, $validation->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_domove', id => $id);
}

# GET /domove/:id
# Display a record from table domove.
sub show($c) {
  my $row = $c->domove->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->domove->find($c->param('id'));
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(domove => $row);
}

# GET /domove
# List resources from table domove.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->domove->all($input));
  }
  return $c->render(domove => $c->domove->all);
}

# DELETE /domove/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->domove->find($input->{id});
    $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      && return
      unless $row;
    $c->domove->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->domove->remove($c->param('id'));
  return $c->redirect_to('home_domove');
}


# Validation for actions that store or update
sub _validation($c) {
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->required('id') if $c->stash->{action} ne 'store';
  $v->required('domain',    'trim')->size(0, 63);
  $v->required('site_name', 'trim')->size(0, 63);
  $v->required('description', 'trim');
  $v->optional('owner_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('group_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('permissions', 'trim')->size(0, 10);
  $v->required('published', 'trim')->like(qr/\d+(\.\d+)?/);

  return $v;
}

1;
