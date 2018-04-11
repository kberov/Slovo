package Slovo::Controller::Celini;
use Mojo::Base 'Slovo::Controller', -signatures;


# GET /celini/create
# Display form for creating resource in table celini.
sub create($c) {
  return $c->render(celini => {});
}

# POST /celini
# Add a new record to table celini.
sub store($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $c->celini->add($in);
    $c->res->headers->location(
                          $c->url_for("api.show_celini", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'create', celini => {}) if $validation->has_error;

  # 2. Insert it into the database
  my $id = $c->celini->add($validation->output);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_celini', id => $id);
}

# GET /celini/:id/edit
# Display form for edititing resource in table celini.
sub edit($c) {
  return $c->render(celini => $c->celini->find($c->param('id')));
}

# PUT /celini/:id
# Update the record in table celini
sub update($c) {

  # Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'edit', celini => {}) if $validation->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->celini->save($id, $validation->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_celini', id => $id);
}

# GET /celini/:id
# Display a record from table celini.
sub show($c) {
  my $row = $c->celini->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->celini->find($c->param('id'));
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(celini => $row);
}

# GET /celini
# List resources from table celini.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->celini->all($input));
  }
  return $c->render(celini => $c->celini->all);
}

# DELETE /celini/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->celini->find($input->{id});
    $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      && return
      unless $row;
    $c->celini->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->celini->remove($c->param('id'));
  return $c->redirect_to('home_celini');
}


# Validation for actions that store or update
sub _validation($c) {
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->required('id') if $c->stash->{action} ne 'store';
  $v->required('alias', 'trim')->size(0, 255);
  $v->optional('pid',     'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('from_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('page_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('user_id',  'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('group_id', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('sorting',     'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('data_type',   'trim')->size(0, 32);
  $v->optional('data_format', 'trim')->size(0, 32);
  $v->required('created_at', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('tstamp', 'trim')->like(qr/\d+(\.\d+)?/);
  $v->required('title', 'trim')->size(0, 255);
  $v->optional('description', 'trim')->size(0, 255);
  $v->optional('keywords',    'trim')->size(0, 255);
  $v->optional('tags',        'trim')->size(0, 100);
  $v->required('body', 'trim');
  $v->optional('box',         'trim')->size(0, 35);
  $v->optional('language',    'trim')->size(0, 5);
  $v->optional('permissions', 'trim')->size(0, 10);
  $v->optional('featured',    'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('accepted',    'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('bad',         'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('deleted',     'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('start',       'trim')->like(qr/\d+(\.\d+)?/);
  $v->optional('stop',        'trim')->like(qr/\d+(\.\d+)?/);

  return $v;
}

1;
