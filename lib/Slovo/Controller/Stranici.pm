package Slovo::Controller::Stranici;

use Mojo::Base 'Slovo::Controller', -signatures;

# GET /<:страница>.стр<*пѫт>
# Display a page in the site
sub execute($c) {
  my $alias = $c->stash->{'страница'};

  #TODO: handle different celini types like въпрос, писанѥ, бележка, книга
  my $path    = $c->stash->{'пѫт'};
  my $user    = $c->user;
  my $preview = $user->{login_name} ne 'guest' && $c->param('прегледъ');
  my $page
    = $c->stranici->find_for_display($alias, $user, $c->domain, $preview);
  $page //= $c->stranici->find($c->not_found_id);
  my $celini = $c->celini->all_for_display($page, $user, 'bg-bg', $preview);

  return
    $c->render(
          template => $page->{template} || 'stranici/stranica',
          page     => $page,
          celini   => $celini,
          $page->{id} == $c->not_found_id ? (status => $c->not_found_code) : (),
    );
}

# Al the following routes are under /Ꙋправленѥ

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

    # TODO: Modify $input: add where clause, get also title in the requested
    # language from celini and merge it into the stranici object. Modify the
    # Swagger description of respons object to conform to the output.
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
  $c->req->param(alias => $c->param('title')) unless $c->param('alias');
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->optional('pid',    'trim')->like(qr/^\d+$/);
  $v->optional('dom_id', 'trim')->like(qr/^\d+$/);
  $v->required('alias', 'slugify')->size(0, 32);
  $v->required('page_type', 'trim')->size(0, 32);
  $v->optional('sorting',     'trim')->like(qr/^\d+$/);
  $v->optional('template',    'trim')->size(0, 255);
  $v->optional('permissions', 'trim')->like(qr/^[dlrwx\-]{10}$/);
  $v->optional('user_id',     'trim')->like(qr/^\d+$/);
  $v->optional('group_id',    'trim')->like(qr/^\d+$/);
  $v->optional('tstamp',      'trim')->like(qr/^\d+$/);
  $v->optional('start',       'trim')->like(qr/^\d+$/);
  $v->optional('stop',        'trim')->like(qr/^\d+$/);
  $v->optional('published',   'trim')->in(2, 1, 0);
  $v->optional('hidden',  'trim')->in(1, 0);
  $v->optional('deleted', 'trim')->in(1, 0);
  $v->optional('changed_by', 'trim')->like(qr/^\d+$/);

  # Page attributes
  $v->required('title', 'xml_escape', 'trim')->size(3, 32);
  $v->optional('body',     'trim');
  $v->optional('title_id', 'trim')->like(qr/^\d+$/);
  $v->required('language', 'trim')->size(5, 5);
  return $v;
}

# GET/api/страници
# List of published pages under a given pid inthe current domain.
# Used for sidedrawer or sitemap
sub list($c) {

  $c->openapi->valid_input or return;
  my $in = $c->validation->output;
  return $c->render(openapi => $c->stranici->all_for_list($in));
}

1;
