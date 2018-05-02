package Slovo::Controller::Stranici;
use Mojo::Base 'Slovo::Controller', -signatures;


# GET /stranici/create
# Display form for creating resource in table stranici.
sub create($c) {
  return $c->render(stranici => {});
}

# POST /stranici
# Add a new record to table stranici.
sub store($c) {
  my $user = $c->user;
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    @$in{qw(user_id group_id changed_by)}
      = ($user->{id}, $user->{group_id}, $user->{id});
    my $id = $c->stranici->add($in);
    $c->res->headers->location(
                        $c->url_for("api.show_stranici", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;
  return $c->render(action => 'create', stranici => {}) if $v->has_error;

  # 2. Insert it into the database
  my $in = $v->output;
  @$in{qw(user_id group_id)} = ($user->{id}, $user->{group_id});

  my $id = $c->stranici->add($in);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  # TODO: make it more user friendly.
  $c->res->headers->location($c->url_for(show_stranici => {id => $id}));
  return $c->render(text => '', status => 201);
}

# GET /stranici/:id/edit
# Display form for edititing resource in table stranici.
sub edit($c) {

  #TODO: implement language switching based on Ado::L18n
  my $l = $c->param('language') || $c->config('default_language');
  my $stranici = $c->stranici->find_for_edit($c->stash('id'), $l);
  return $c->render(stranici => $stranici);
}

# PUT /stranici/:id
# Update the record in table stranici
sub update($c) {

  # Validate input
  my $v = $c->_validation;
  return $c->render(action => 'edit', stranici => {}) if $v->has_error;

  # Update the record
  my $id = $c->param('id');
  $c->stranici->save($id, $v->output);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  return $c->redirect_to('show_stranici', id => $id);
}

# GET /stranici/:id
# Display a record from table stranici.
sub show($c) {
  my $row = $c->stranici->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return
      $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->stranici->find($c->param('id'));
  return $c->render(text => $c->res->default_message(404), status => 404)
    unless $row;
  return $c->render(stranici => $row);
}

# GET /stranici
# List resources from table stranici.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->stranici->all($input));
  }
  return $c->render(stranici => $c->stranici->all);
}

# DELETE /stranici/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->stranici->find($input->{id});
    $c->render(
         openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
         status  => 404)
      && return
      unless $row;
    $c->stranici->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  $c->stranici->remove($c->param('id'));
  return $c->redirect_to('home_stranici');
}


# Validation for actions that store or update
sub _validation($c) {
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->optional('pid',    'trim')->like(qr/^\d+$/);
  $v->optional('dom_id', 'trim')->like(qr/^\d+$/);
  $v->required('alias',     'trim')->size(0, 32);
  $v->required('page_type', 'trim')->size(0, 32);
  $v->optional('sorting',     'trim')->like(qr/^\d+$/);
  $v->optional('template',    'trim')->size(0, 255);
  $v->optional('permissions', 'trim')->size(0, 10);
  $v->optional('user_id',     'trim')->like(qr/^\d+$/);
  $v->optional('group_id',    'trim')->like(qr/^\d+$/);
  $v->optional('tstamp',      'trim')->like(qr/^\d+$/);
  $v->optional('start',       'trim')->like(qr/^\d+$/);
  $v->optional('stop',        'trim')->like(qr/^\d+$/);
  $v->optional('published',   'trim')->like(qr/^\d+$/);
  $v->optional('hidden',      'trim')->like(qr/^\d+$/);
  $v->optional('deleted',     'trim')->like(qr/^\d+$/);
  $v->optional('changed_by',  'trim')->like(qr/^\d+$/);

  # Page attributes
  $v->required('title', 'xml_escape', 'trim')->size(3, 32);
  $v->optional('body',     'trim');
  $v->optional('title_id', 'trim')->like(qr/^\d+$/);
  $v->required('language', 'trim')->size(5, 5);
  return $v;
}

1;
