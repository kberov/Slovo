package Slovo::Controller::Celini;
use Mojo::Base 'Slovo::Controller', -signatures;

use Role::Tiny::With;
with 'Slovo::Controller::Role::Stranica';
use Mojo::Collection 'c';

my sub _redirect_to_new_celina_url ($c, $page, $celina) {

  # https://tools.ietf.org/html/rfc7538#section-3
  my $status = $c->req->method =~ /GET|HEAD/i ? 301 : 308;
  $c->res->code($status);
  return $c->redirect_to(
    para_with_lang => {
      paragraph_alias => $celina->{alias},
      page_alias      => $page->{alias},
      lang            => $celina->{language}});
}

# Prepares collection of parent ids of celiny in which a celina can be put.
my sub _celini_options ($c, $id, $page_id, $user, $l) {
  my $celini = $c->celini;
  my $opts   = {
    where => {
      page_id => $page_id,
      $id ? (id => {'!=' => $id}) : (), %{$celini->writable_by($user)},
      language    => $celini->language_like($l),
      permissions => {-like => 'd%'}}};
  my $options = $celini->all($opts)->map(sub { ["„$_->{title}”" => $_->{id}] });
  unshift @$options, ['Въ никоѭ' => 0];
  return $options;
}

# ANY /<page_alias:str>/<paragraph_alias:cel>.<lang:lng>.html
# ANY /<page_alias:str>/<paragraph_alias:cel>.html
# Display a content element in a page in the site.
sub execute ($c, $page, $user, $l, $preview) {

  # TODO celina breadcrumb
  #my $path = [split m|/|, $c->stash->{'paragraph'}];
  #my $path = $c->celini->breadcrumb($p_alias, $path, $l, $user, $preview);
  my $stash  = $c->stash;
  my $alias  = $stash->{'paragraph_alias'};
  my $celina = $c->celini->find_for_display($alias, $user, $l, $preview,
    {page_id => $page->{id}, box => $stash->{boxes}[0]});

  unless ($celina) {
    $celina = $c->celini->find_where(
      {page_id => $c->not_found_id, language => $l, data_type => 'title'});
    return $c->render(celina => $celina, status => $c->not_found_code);
  }

  # Celina was found, but with a new alias.
  return $c->_redirect_to_new_celina_url($page, $celina) if $celina->{alias} ne $alias;
  return $c->is_fresh(last_modified => $celina->{tstamp})
    ? $c->rendered(304)
    : $c->render(
    celina          => $celina,
    paragraph_alias => $celina->{alias},
    lang            => $celina->{language});
}

# Check for pid and page_id parameters and redirect to pages' index page if
# needed, so the user can choose in which page to create the new writing.
my sub _validate_create ($c, $u, $l, $str) {
  my $int = qr/^\d{1,10}$/;
  my $v   = $c->validation;
  $v->optional(page_id => 'trim')->like($int);
  $v->optional(pid     => 'trim')->like($int);
  my $in         = $v->output;
  my $celini     = $c->celini;
  my $data_types = $c->stash('data_types');
  my $root       = $str->find_where(
    {dom_id => $c->stash('domain')->{id}, page_type => $str->root_page_type});

  if (!defined $in->{pid} && !defined $in->{page_id}) {
    $c->flash(message => 'Няма подаден номер на страница! '
        . 'Изберете страница, в която да създадете новото писанѥ!');
    $c->redirect_to($c->url_for('home_stranici')->query(pid => $root->{id}));
    return;
  }
  elsif (defined $in->{pid} && !defined $in->{page_id}) {
    my $cel = $celini->find_where({
      pid      => $in->{pid},
      language => $celini->language_like($l),
      %{$celini->writable_by($u)}});
    unless ($cel) {
      $c->flash(message => 'Нямате права да пишете в раздел с номер '
          . $in->{pid}
          . '. Изберете страница, в която да създадете новото писанѥ!');
      $c->redirect_to($c->url_for('home_stranici')->query(pid => $root->{id}));
      return;
    }
    $in->{page_id} = $cel->{page_id};
  }
  elsif (!defined $in->{pid} && defined $in->{page_id}) {
    my $cel = $celini->find_where({
      page_id   => $in->{page_id},
      data_type => $data_types->[0],             # note
      language  => $celini->language_like($l),
      %{$celini->writable_by($u)}});
    unless ($cel) {
      $c->flash(message => 'Нямате права да пишете в страница с номер '
          . $in->{page_id}
          . '. Изберете страница, в която да създадете новото писанѥ!');
      $c->redirect_to($c->url_for('home_stranici')->query(pid => $root->{id}));
      return;
    }
    $in->{pid} = $cel->{id};

  }
  return $in;
}

# GET /celini/create
# Display form for creating resource in table celini.
sub create ($c) {
  my $str = $c->stranici;
  my $l   = $c->language;
  my $u   = $c->user;

  my $in    = _validate_create($c, $u, $l, $str) // return;
  my $bread = $str->breadcrumb($in->{page_id}, $l);
  return $c->render(
    breadcrumb    => $bread,
    in            => $in,
    parent_celini => _celini_options($c, 0, $in->{page_id}, $u, $l),
  );
}

# POST /celini
# Add a new record to table celini.
sub store ($c) {
  my $user = $c->user;
  my $in   = {};
  @$in{qw(user_id group_id changed_by created_at)}
    = ($user->{id}, $user->{group_id}, $user->{id}, time - 1);

  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    $in = {%{$c->validation->output}, %$in};
    my $id = $c->celini->add($in);
    $c->res->headers->location($c->url_for("api.show_celini", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;
  $in = {%{$v->output}, %$in};
  if ($v->has_error) {
    my $l = $c->language;
    return $c->render(
      action        => 'create',
      in            => $in,
      breadcrumb    => $c->stranici->breadcrumb($in->{page_id}, $l),
      parent_celini => _celini_options($c, 0, $in->{page_id}, $user, $l),
    );
  }

  # 2. Insert it into the database
  $in = {%{$v->output}, %$in};
  my $id = $c->celini->add($in);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  return $c->redirect_to('show_celini', id => $id);
}

# GET /celini/:id/edit
# Display form for edititing resource in table celini.
sub edit ($c) {
  my $row = $c->celini->find($c->param('id'));

  # prefill form fields.
  $c->req->param($_ => $row->{$_}) for keys %$row;
  my $str   = $c->stranici;
  my $l     = $c->language;
  my $bread = $str->breadcrumb($row->{page_id}, $l);
  return $c->render(
    breadcrumb    => $bread,
    in            => $row,
    parent_celini => _celini_options($c, $row->{id}, $row->{page_id}, $c->user, $l),
  );
}

# PUT /celini/:id
# Update the record in table celini
sub update ($c) {

  # Validate input
  my $v  = $c->_validation;
  my $in = $v->output;

  if ($v->has_error) {
    my $l    = $c->language;
    my $user = $c->user;
    return $c->render(
      action        => 'edit',
      in            => $in,
      breadcrumb    => $c->stranici->breadcrumb($in->{page_id}, $l),
      parent_celini => _celini_options($c, 0, $in->{page_id}, $user, $l),
    );
  }

  # Update the record
  my $id = $c->stash('id');
  $c->celini->save($id, $in);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  my $redirect = $c->param('redirect') // '';
  return $c->redirect_to($redirect, id => $id) if $redirect eq 'show_celini';
  return $c->render(text => '', status => 204);
}

# GET /celini/:id
# Display a record from table celini.
sub show ($c) {
  my $row = $c->celini->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
    ) unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->celini->find($c->param('id'));
  return $c->render(text   => $c->res->default_message(404), status => 404) unless $row;
  return $c->render(celini => $row);
}

# GET /celini
# List resources from table celini in the current domain.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index ($c) {

  # restrict to the current domain root page
  my $str = $c->stranici;
  my $l   = $c->language;

  # check if such page id exists.
  my $page_ids = $str->all({
    columns => 'id',
    where   => {dom_id => $c->stash('domain')->{id}, %{$str->readable_by($c->user)}}
  })->map(sub { $_->{id} });
  my $param_page_id = $c->param('page_id');
  my $page_id
    = defined $param_page_id
    ? $page_ids->first(sub { $_ eq $param_page_id })
    : $page_ids->[0];

  # TODO - invoked via OpenAPI
  if ($c->current_route =~ /^api\./) {
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    return $c->render(openapi => $c->celini->all($input));
  }
  my $celini = $c->celini;
  my $opts   = {
    where    => {page_id => $page_id, %{$celini->readable_by($c->user)}},
    order_by => {-asc    => [qw(page_id pid sorting id)]}};

  return $c->render(
    celini     => $celini->all($opts),
    page_id    => $page_id,
    breadcrumb => $str->breadcrumb($page_id, $l));
}

# DELETE /celini/:id
sub remove ($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->celini->find($input->{id});
    $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
      )
      && return
      unless $row;
    $c->celini->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  my $id  = $c->stash('id');
  my $cel = $c->celini->find_where({'id' => $id, %{$c->celini->writable_by($c->user)}});
  if ($id) {
    $c->celini->remove($id);
  }
  else {
    return !$c->redirect_to(edit_celini => {id => $c->param('id')});
  }
  return $c->redirect_to(celini_in_stranica => page_id => $cel->{page_id});
}


# Validation for actions that store or update
# Validation rules for the record to be stored in the database
sub _validation ($c) {
  $c->req->param(alias => $c->param('title')) unless $c->param('alias');
  for (qw(featured accepted bad deleted)) {
    $c->req->param($_ => 0) unless $c->param($_);
  }
  my $v     = $c->validation;
  my $types = $c->stash('data_types');
  $v->required('data_type', 'trim')->in(@$types);
  my $alias = 'optional';
  my $title = $alias;
  my $pid   = $alias;

  # For all but the last two types the following properties are required
  my $types_rx = join '|', @$types[0 .. @$types - 2];
  my $dt       = $v->param('data_type') // '';
  if ($dt =~ /^($types_rx)$/x) {
    $title = $alias = 'required';
  }

  # for answer pid is required
  elsif ($dt =~ /^($types->[-2])$/x) {
    $pid = 'required';
  }
  my $int = qr/^\d{1,10}$/;
  $v->$alias('alias', 'slugify')->size(0, 255);
  $v->$title('title', 'xml_escape', 'trim')->size(0, 255);
  $v->$pid('pid', 'not_empty', 'trim')->like($int);
  $v->optional('from_id', 'trim')->like($int);
  $v->required('page_id', 'not_empty', 'trim')->like($int);
  $v->optional('user_id',  'trim')->like($int);
  $v->optional('group_id', 'trim')->like($int);
  $v->optional('sorting',  'trim')->like(qr/^\d{1,3}$/);

  $v->required('data_format', 'trim')->in(@{$c->stash->{data_formats}});
  $v->optional('description', 'trim')->size(0, 255);
  $v->optional('keywords',    'trim')->size(0, 255);
  $v->optional('tags',        'trim')->size(0, 100);
  $v->required('body', 'trim');
  $v->optional('box',         'trim')->size(0, 35)->in(@{$c->stash->{boxes}});
  $v->optional('language',    'trim')->size(0, 5);
  $v->optional('permissions', 'trim')->is(\&writable, $c);
  $v->optional('featured',    'trim')->in(1, 0);
  $v->optional('accepted',    'trim')->in(1, 0);
  $v->optional('bad',         'trim')->like($int);
  $v->optional('deleted',     'trim')->in(1, 0);
  $v->optional('start',       'trim')->like($int);
  $v->optional('stop',        'trim')->like($int);
  $v->optional('published',   'trim')->in(2, 1, 0);
  $c->b64_images_to_files('body');
  return $v;
}

1;
