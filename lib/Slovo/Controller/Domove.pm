package Slovo::Controller::Domove;
use Mojo::Base 'Slovo::Controller', -signatures;

# GET /domove/create
# Display form for creating resource in table domove.
sub create ($c) {
  return $c->render(in => {});
}

# POST /domove
# Add a new record to table domove.
sub store ($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    my $id = $c->domove->add($in);
    $c->res->headers->location($c->url_for("api.show_domove", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;
  return $c->render(action => 'create', in => {}) if $v->has_error;

  # 2. Insert it into the database
  my $id = $c->domove->add($v->output);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_domove', id => $id);
}

# GET /domove/:id/edit
# Display form for edititing resource in table domove.
sub edit ($c) {
  my $row = $c->domove->find($c->param('id'));
  $c->req->param($_ => $row->{$_}) for keys %$row;    # prefill form fields.
  return $c->render(in => $row);
}

# PUT /domove/:id
# Update the record in table domove
sub update ($c) {

  # Validate input
  my $v = $c->_validation;
  return $c->render(action => 'edit') if $v->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->domove->save($id, $v->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_domove', id => $id);
}

# GET /domove/:id
# Display a record from table domove.
sub show ($c) {
  my $id  = $c->param('id');
  my $row = $c->domove->find($id);
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
    ) unless $row;
    return $c->render(openapi => $row);
  }
  return $c->render(text => $c->res->default_message(404), status => 404) unless $row;
  return $c->render(dom  => $row);
}

# GET /domove
# List resources from table domove.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index ($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->domove->all($input));
  }
  return $c->render(domove => $c->domove->all);
}

# DELETE /domove/:id
sub remove ($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->domove->find($input->{id});
    $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
      )
      && return
      unless $row;
    $c->domove->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->domove->remove($c->param('id'));
  return $c->redirect_to('home_domove');
}


# Validation for actions that store or update
sub _validation ($c) {
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->required('domain', 'trim')->size(0, 63);
  $v->optional('aliases', 'trim')->like(qr/[a-z0-9\-\.\s]{1,2000}/);
  $v->required('site_name',   'trim')->size(0, 63);
  $v->required('description', 'trim')->size(0, 2000);
  $v->optional('owner_id',    'trim')->like(qr/^\d+$/a);
  $v->optional('group_id',    'trim')->like(qr/^\d+$/a);
  $v->optional('permissions', 'trim')->like(qr/^[dlrwx\-]{10}$/);
  $v->optional('templates',   'trim',)->like(qr/^[\w\/]{0,255}$/);
  $v->required('published', 'trim')->like(qr/^[0-2]$/);

  return $v;
}

1;
