package Slovo::Controller::Stranici;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

use Role::Tiny::With;
with 'Slovo::Controller::Role::Stranica';

# ANY /<страница:str>.<ѩꙁыкъ:lng>.html
# ANY /<страница:str>.html
# Display a page in the site
sub execute ($c, $page, $user, $l, $preview) {

  # Make the root page looks like just updated when max_age elapsed and the
  # browser makes a request again, because it is very rarely directly
  # updated.
  my $refresh_root = $page->{page_type} eq 'коренъ';
  return $c->is_fresh(last_modified => $refresh_root ? time : $page->{tstamp})
    ? $c->rendered(304)
    : $c->render();
}

# All the following routes are under /Ꙋправленѥ

# GET /stranici/create
# Display form for creating resource in table stranici.
sub create($c) {

  state $formats     = $c->openapi_spec('/parameters/data_format/enum');
  state $languages   = $c->openapi_spec('/parameters/language/enum');
  state $permissions = $c->openapi_spec('/parameters/permissions/enum');
  my $str    = $c->stranici;
  my $l      = $c->language;
  my $domove = $c->domove->all->map(sub { [$_->{site_name} => $_->{id}] });
  my $pid    = $c->param('pid') // 0;
  my $bread  = $str->breadcrumb($pid, $l);
  my $u      = $c->user;
  my $domain = $c->host_only;
  return $c->render(
    in          => {},
    domove      => $domove,
    l           => $l,
    formats     => $formats,
    languages   => $languages,
    permissions => $permissions,
    u           => $u,
    breadcrumb  => $bread,
    parents     => $c->page_id_options($bread, {pid => $pid}, $u, $domain, $l),
  );
}

# POST /stranici
# Add a new record to table stranici.
sub store($c) {
  my $user = $c->user;
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $in = $c->validation->output;
    @$in{qw(user_id group_id changed_by)} = ($user->{id}, $user->{group_id}, $user->{id});
    my $id = $c->stranici->add($in);
    $c->res->headers->location($c->url_for("api.show_stranici", id => $id)->to_string);
    return $c->render(openapi => '', status => 201);
  }

  # 1. Validate input
  my $v = $c->_validation;
  return $c->render(action => 'create', in => {}) if $v->has_error;

  # 2. Insert it into the database
  my $in = $v->output;
  @$in{qw(user_id group_id)} = ($user->{id}, $user->{group_id});

  my $id = $c->stranici->add($in);

  # 3. Prepare the response data or just return "201 Created"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/201
  # TODO: make it more user friendly.
  return $c->redirect_to(edit_stranici => {id => $id});
}


# GET /stranici/:id/edit
# Display form for edititing resource in table stranici.
sub edit($c) {

  state $formats     = $c->openapi_spec('/parameters/data_format/enum');
  state $languages   = $c->openapi_spec('/parameters/language/enum');
  state $permissions = $c->openapi_spec('/parameters/permissions/enum');
  my $str = $c->stranici;
  my $l   = $c->language;
  my $u   = $c->user;
  my $row = $str->find_for_edit($c->stash('id'), $l);

  my $domove = $c->domove->all->map(sub { [$_->{site_name} => $_->{id}] });
  my $bread  = $str->breadcrumb($row->{id}, $l);
  my $domain = $c->host_only;

  #TODO: implement language switching based on Ado::L18n
  $c->req->param($_ => $row->{$_}) for keys %$row;    # prefill form fields.
  return $c->render(
    domove      => $domove,
    l           => $l,
    in          => $row,
    formats     => $formats,
    languages   => $languages,
    permissions => $permissions,
    u           => $u,
    breadcrumb  => $bread,
    parents     => $c->page_id_options($bread, $row, $u, $domain, $l),
  );
}

# PUT /stranici/:id
# Update the record in table stranici
sub update($c) {

  # Validate input
  my $v  = $c->_validation;
  my $in = $v->output;

  #TODO: Make proper error displaying for flash mesages and/or just make sure
  #all stash variables are prepared and error messages are displayed near the
  #failed fields ot in this page
  if ($v->has_error) {
    $c->flash(message => 'Failed validation for: ' . join(', ', @{$v->failed}));
    return $c->redirect_to('edit_stranici', id => $c->stash->{id});
  }

  # Update the record
  my $id = $c->param('id');
  $c->stranici->save($id, $in);

  # Redirect to the updated record or just send "204 No Content"
  # See https://developer.mozilla.org/docs/Web/HTTP/Status/204
  my $redirect = $c->param('redirect') // '';
  return $c->redirect_to($redirect, id => $id) if $redirect eq 'show_stranici';
  return $c->render(text => '', status => 204);
}

# GET /stranici/:id
# Display a record from table stranici.
sub show($c) {
  my $row = $c->stranici->find($c->param('id'));
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    return $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
    ) unless $row;
    return $c->render(openapi => $row);
  }
  $row = $c->stranici->find($c->param('id'));
  return $c->render(text     => $c->res->default_message(404), status => 404) unless $row;
  return $c->render(stranici => $row);
}

# GET /stranici
# List resources from table stranici.
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  my $str = $c->stranici;
  state $list_columns
    = $c->openapi_spec('/paths/~1страници/get/parameters/4/default');
  my $domain = $c->host_only;
  my $v      = $c->validation;

  $v->optional(pid => 'trim')->like(qr/^\d+$/);
  my $in   = $v->output;
  my $l    = $c->language;
  my $user = $c->user;
  my $columns
    = [@$list_columns, qw(start stop user_id group_id permissions deleted hidden dom_id)];

  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;

    # TODO: Modify $in: add where clause, get also title in the requested
    # language from celini and merge it into the stranici object. Modify the
    # Swagger description of response object to conform to the output.
    return $c->render(openapi => $str->all($in));
  }

  return $c->render(
    user       => $user,
    domain     => $domain,
    columns    => $columns,
    l          => $l,
    breadcrumb => $str->breadcrumb($in->{pid}, $l),
  );
}

# DELETE /stranici/:id
sub remove($c) {
  if ($c->current_route =~ /^api\./) {    #invoked via OpenAPI
    $c->openapi->valid_input or return;
    my $input = $c->validation->output;
    my $row   = $c->stranici->find($input->{id});
    $c->render(
      openapi => {errors => [{path => $c->url_for, message => 'Not Found'}]},
      status  => 404
      )
      && return
      unless $row;
    $c->stranici->remove($input->{id});
    return $c->render(openapi => '', status => 204);
  }
  my $id = $c->param('id');
  my $v  = $c->validation->input({id => $id});
  $v->required('id');
  $v->error('id' => ['not_writable'])
    unless $c->stranici->find_where(
    {'id' => $id, %{$c->stranici->writable_by($c->user)}});
  my $in = $v->output;
  if ($in->{id}) {
    $c->stranici->remove($in->{id});
  }
  else {
    return !$c->redirect_to(edit_stranici => {id => $c->param('id')});
  }
  return $c->redirect_to('home_stranici');
}

# Validation for actions that store or update
sub _validation($c) {
  $c->req->param(alias => $c->param('title')) unless $c->param('alias');
  for (qw(hidden deleted)) {
    $c->req->param($_ => 0) unless $c->param($_);
  }
  my $v = $c->validation;

  # Add validation rules for the record to be stored in the database
  # If we edit an existing page, check if the page is writable by the
  # current user.
  $v->optional('pid',    'trim')->like(qr/^\d+$/);
  $v->optional('dom_id', 'trim')->like(qr/^\d+$/);
  $v->required('alias', 'slugify')->size(0, 32);
  $v->required('page_type', 'trim')->size(0, 32);
  $v->optional('sorting',     'trim')->like(qr/^\d+$/);
  $v->optional('template',    'trim')->size(0, 255);
  $v->optional('user_id',     'trim')->like(qr/^\d+$/);
  $v->optional('group_id',    'trim')->like(qr/^\d+$/);
  $v->optional('permissions', 'trim')->is(\&writable, $c);
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

  state $formats   = $c->openapi_spec('/parameters/data_format/enum');
  state $languages = $c->openapi_spec('/parameters/language/enum');
  $v->required('language',    'trim')->in(@$languages);
  $v->required('data_format', 'trim')->in(@$formats);
  $c->b64_images_to_files('body');
  return $v;
}

# GET/api/страници
# List of published pages under a given pid in the current domain.
# Used for sidedrawer or sitemap
sub list($c) {

  $c->openapi->valid_input or return;
  my $in      = $c->validation->output;
  my $user    = $c->user;
  my $preview = $c->is_user_authenticated && $c->param('прегледъ');
  my $list
    = $c->stranici->all_for_list($user, $c->host_only, $preview, $c->language, $in);
  return $c->render(openapi => $list);
}

1;
