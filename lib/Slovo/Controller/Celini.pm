package Slovo::Controller::Celini;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";


# GET /celini/create
# Display form for creating resource in table celini.
sub create($c) {
  return $c->render(in => {});
}

# POST /celini
# Add a new record to table celini.
sub store($c) {
  my $user = $c->user;
  my $in   = {};
  @$in{qw(user_id group_id changed_by created_at)}
    = ($user->{id}, $user->{group_id}, $user->{id}, time - 1);

  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    $in = {%{$c->validation->output}, %$in};
    my $id = $c->celini->add($in);
    $c->res->headers->location(
                          $c->url_for("api.show_celini", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;
  return $c->render(action => 'create', celini => {}) if $v->has_error;

  # 2. Insert it into the database
  $in = {%{$v->output}, %$in};
  my $id = $c->celini->add($in);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_celini', id => $id);
}

# GET /celini/:id/edit
# Display form for edititing resource in table celini.
sub edit($c) {
  my $row = $c->celini->find($c->param('id'));
  $c->req->param($_ => $row->{$_}) for keys %$row;    # prefill form fields.
  return $c->render(in => $row);
}

# PUT /celini/:id
# Update the record in table celini
sub update($c) {

  # Validate input
  my $validation = $c->_validation;
  return $c->render(action => 'edit', in => {}) if $validation->has_error;

  # Update the record
  my $id = $c->stash('id');
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

  my $v = $c->validation;
  $v->optional('page_id', 'trim')->like(qr/^\d+$/);
  my $o    = $v->output;
  my $opts = {};

  if (defined $o->{page_id}) {
    $opts->{where}{page_id} = $o->{page_id};
  }
  $opts->{order_by} = {-asc => [qw(page_id pid sorting id)]};
  return $c->render(celini => $c->celini->all($opts));
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
  $c->req->param(alias => $c->param('title')) unless $c->param('alias');
  for (qw(featured accepted bad deleted)) {
    $c->req->param($_ => 0) unless $c->param($_);
  }
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  $v->optional('data_type', 'trim')->size(0, 32)->in(
                                                     'въпросъ', 'ѿговоръ',
                                                     'писанѥ',  'белѣжка',
                                                     'книга',   'заглавѥ',
                                                     'цѣлина'
                                                    );
  my $alias   = 'optional';
  my $title   = $alias;
  my $page_id = $alias;
  my $types   = 'книга|въпросъ|писанѥ|белѣжка';
  if ($v->param('data_type') =~ /^($types)$/x) {
    $page_id = $title = $alias = 'required';
  }
  $v->$alias('alias', 'slugify')->size(0, 255);
  $v->$title('title', 'xml_escape', 'trim')->size(0, 255);
  $v->optional('pid',     'trim')->like(qr/^\d+$/);
  $v->optional('from_id', 'trim')->like(qr/^\d+$/);
  $v->$page_id('page_id', 'trim')->like(qr/^\d+$/);
  $v->optional('user_id',     'trim')->like(qr/^\d+$/);
  $v->optional('group_id',    'trim')->like(qr/^\d+$/);
  $v->optional('sorting',     'trim')->like(qr/^\d{1,3}$/);
  $v->optional('data_format', 'trim')->size(0, 32);
  $v->optional('description', 'trim')->size(0, 255);
  $v->optional('keywords',    'trim')->size(0, 255);
  $v->optional('tags',        'trim')->size(0, 100);
  $v->required('body', 'trim');
  $v->optional('box', 'trim')->size(0, 35)
    ->in(qw(main главна top горѣ left лѣво right дѣсно bottom долу));
  $v->optional('language', 'trim')->size(0, 5);
  $v->optional('permissions', 'trim')->like(qr/^[dlrwx\-]{10}$/);
  $v->optional('featured',    'trim')->in(1, 0);
  $v->optional('accepted',    'trim')->in(1, 0);
  $v->optional('bad',         'trim')->like(qr/^\d+$/);
  $v->optional('deleted',     'trim')->in(1, 0);
  $v->optional('start',       'trim')->like(qr/^\d{1,10}$/);
  $v->optional('stop',        'trim')->like(qr/^\d{1,10}$/);
  $v->optional('published',   'trim')->in(2, 1, 0);
  return $v;
}

1;
