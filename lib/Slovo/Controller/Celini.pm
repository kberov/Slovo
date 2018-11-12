package Slovo::Controller::Celini;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Role::Tiny::With;
with 'Slovo::Controller::Role::Stranica';

# ANY /<страница:str>/<цѣлина:cel>.<ѩꙁыкъ:lng>.html
# ANY /<:страница:str>/<цѣлина:cel>.html
# Display a content element in a page in the site.
sub execute ($c, $page, $user, $l, $preview) {

  # TODO celina breadcrumb
  #my $path = [split m|/|, $c->stash->{'цѣлина'}];
  #my $path = $c->celini->breadcrumb($p_alias, $path, $l, $user, $preview);
  my $alias = $c->stash->{'цѣлина'};
  my $celina =
    $c->celini->find_for_display(
                                 $alias, $user, $l, $preview,
                                 {
                                  pid     => $c->stash->{celini}[0]{id},
                                  page_id => $page->{id}
                                 }
                                );

  # Celina was found, but with a new alias.
  return $c->_go_to_new_celina_url($page, $celina, $l)
    if $celina && $celina->{alias} ne $alias;

  unless ($celina) {
    $celina = $c->celini->find_where(
         {page_id => $c->not_found_id, language => $l, data_type => 'заглавѥ'});
    return $c->render(celina => $celina, status => $c->not_found_code);
  }
  return $c->is_fresh(last_modified => $celina->{tstamp})
    ? $c->rendered(304)
    : $c->render(celina => $celina, 'цѣлина' => $celina->{alias});
}

sub _go_to_new_celina_url ($c, $page, $celina, $l) {

  # https://tools.ietf.org/html/rfc7538#section-3
  my $status = $c->req->method =~ /GET|HEAD/i ? 301 : 308;
  $c->res->code($status);
  return
    $c->redirect_to(
                    'цѣлина_с_ѩꙁыкъ' => {
                                         'цѣлина'   => $celina->{alias},
                                         'страница' => $page->{alias},
                                         'ѩꙁыкъ'    => $l
                                        }
                   );
}

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
  return $c->render(action => 'create', celini => {},
                    in => {%{$v->output}, %$in})
    if $v->has_error;

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
  my $v  = $c->_validation;
  my $in = $v->output;
  return $c->render(action => 'edit', in => $in) if $v->has_error;

  # Update the record
  my $id = $c->stash('id');
  $c->celini->save($id, $in);

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
# List resources from table celini in the current domain.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {

  # restrict to the current domain root page
  my $str = $c->stranici;
  my $in
    = $str->all(
             {columns => 'id', where => {$str->where_domain_is($c->host_only)}})
    ->map(sub { $_->{id} })->to_array;
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->celini->all($input));
  }
  my $v = $c->validation;
  $v->optional('page_id', 'trim')->in(@$in);
  my $o      = $v->output;
  my $celini = $c->celini;
  my $opts   = {where => {%{$celini->readable_by($c->user)}}};

  if (defined $o->{page_id}) {
    $opts->{where}{page_id} = $o->{page_id};
  }
  else {
    $opts->{where}{page_id} = {-in => $in};
  }
  $opts->{order_by} = {-asc => [qw(page_id pid sorting id)]};
  return $c->render(celini => $celini->all($opts));
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
  my $id = $c->param('id');
  my $v = $c->validation->input({id => $id});
  $v->required('id');
  $v->error('id' => ['not_writable'])
    unless $c->celini->find_where(
                           {'id' => $id, %{$c->celini->writable_by($c->user)}});
  my $in = $v->output;
  if ($in->{id}) {
    $c->celini->remove($in->{id});
  }
  else {
    return !$c->redirect_to(edit_celini => {id => $c->param('id')});
  }
  return $c->redirect_to('home_celini');
}


# Validation for actions that store or update
# Validation rules for the record to be stored in the database
sub _validation($c) {
  $c->req->param(alias => $c->param('title')) unless $c->param('alias');
  for (qw(featured accepted bad deleted)) {
    $c->req->param($_ => 0) unless $c->param($_);
  }
  my $v = $c->validation;

  state $types = $c->openapi_spec('/parameters/data_type/enum');
  $v->required('data_type', 'trim')->in(@$types);
  my $alias = 'optional';
  my $title = $alias;
  my $pid   = $alias;

  # For all but the last two types the following properties are required
  my $types_rx = join '|', @$types[0 .. @$types - 2];
  my $dt = $v->param('data_type') // '';
  if ($dt =~ /^($types_rx)$/x) {
    $title = $alias = 'required';
  }

  # for ѿговоръ pid is required
  elsif ($dt =~ /^($types->[-2])$/x) {
    $pid = 'required';
  }
  $v->$alias('alias', 'slugify')->size(0, 255);
  $v->$title('title', 'xml_escape', 'trim')->size(0, 255);
  $v->$pid('pid', 'trim')->like(qr/^\d+$/);
  $v->optional('from_id', 'trim')->like(qr/^\d+$/);
  $v->required('page_id', 'trim')->like(qr/^\d+$/);
  $v->optional('user_id',  'trim')->like(qr/^\d+$/);
  $v->optional('group_id', 'trim')->like(qr/^\d+$/);
  $v->optional('sorting',  'trim')->like(qr/^\d{1,3}$/);

  state $formats = $c->openapi_spec('/parameters/data_format/enum');
  $v->required('data_format', 'trim')->in(@$formats);
  $v->optional('description', 'trim')->size(0, 255);
  $v->optional('keywords',    'trim')->size(0, 255);
  $v->optional('tags',        'trim')->size(0, 100);
  $v->required('body', 'trim');
  $v->optional('box', 'trim')->size(0, 35)
    ->in(qw(main главна top горѣ left лѣво right дѣсно bottom долу));
  $v->optional('language', 'trim')->size(0, 5);
  $v->optional('permissions', 'trim')->is(\&writable, $c);
  $v->optional('featured', 'trim')->in(1, 0);
  $v->optional('accepted', 'trim')->in(1, 0);
  $v->optional('bad',      'trim')->like(qr/^\d+$/);
  $v->optional('deleted',  'trim')->in(1, 0);
  $v->optional('start',    'trim')->like(qr/^\d{1,10}$/);
  $v->optional('stop',     'trim')->like(qr/^\d{1,10}$/);
  $v->optional('published', 'trim')->in(2, 1, 0);
  $c->b64_images_to_files('body');
  return $v;
}

1;
