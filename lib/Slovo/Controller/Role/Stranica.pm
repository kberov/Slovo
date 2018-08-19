package Slovo::Controller::Role::Stranica;
use Mojo::Base -role, -signatures;
use Mojo::File 'path';
use Mojo::ByteStream 'b';
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

around execute => sub ($execute, $c) {
  state $cache_pages = $c->config('cache_pages');
  my $preview = $c->is_user_authenticated && $c->param('прегледъ');
  return 1 if $cache_pages && !$preview && $c->_render_cached_page();

  my $alias = $c->stash->{'страница'};
  my $l     = $c->language;
  state $json_path      = '/paths/~1страници/get/parameters/4/default';
  state $list_columns   = $c->openapi_spec($json_path);
  state $not_found_id   = $c->not_found_id;
  state $not_found_code = $c->not_found_code;
  my $user = $c->user;

  my $str = $c->stranici;
  my $page = $str->find_for_display($alias, $user, $c->host_only, $preview);
  $page //= $str->find($not_found_id);
  $page->{is_dir} = $page->{permissions} =~ /^d/;
  $c->stash($page->{template} ? (template => $page->{template}) : ());
  my $celini
    = $c->celini->all_for_display_in_stranica($page, $user, $l, $preview);

  #These are always used so we add them to the stash earlier.
  $c->stash(
    celini       => $celini,
    list_columns => $list_columns,
    page         => $page,
    preview      => $preview,
    user         => $user,

    # data_type to template name
    d2t => {
            'белѣжка' => '_beleyazhka',
            'въпросъ' => '_wyprosy',
            'заглавѥ' => '_zaglawie',
            'книга'   => '_kniga',
            'писанѥ'  => '_pisanie',
            'цѣлина'  => '_ceyalina',
            'ѿговоръ' => '_otgowory'
           },
  );

  if ($page->{id} == $not_found_id) {
    $c->stash(breadcrumb => []);
    $c->stash(status     => $not_found_code);
    return $c->render();
  }
  $c->stash(breadcrumb => $str->breadcrumb($page->{id}, $l));
  my $ok = $execute->($c, $page, $user, $l, $preview);

  # Cache this page on disk if user is not authenticated.
  $c->_cache_page() if $cache_pages && !$c->is_user_authenticated;
  return $ok;
};

my $cached    = 'cached';
my $cacheable = qr/\.html$/;

sub _render_cached_page($c) {
  my $url_path = $c->req->url->path->canonicalize->leading_slash(0)->to_route;
  return unless $url_path =~ $cacheable;
  my $file = path($c->app->static->paths->[0], $cached, $url_path);
  return $c->render(text => b($file->slurp)->decode) if -f $file;
  return;
}

sub _cache_page($c) {
  my $url_path = $c->req->url->path->canonicalize->leading_slash(0)->to_route;
  return unless $url_path =~ $cacheable;
  my $file = path($c->app->static->paths->[0], $cached, $url_path);
  $file->dirname->make_path({mode => oct(700)});

  # This file will be deleteted automatically when the page or its заглавѥ is
  # changed.
  return $file->spurt($c->res->body =~ s/<html>/<html><!-- $cached -->/r);
}

# Delete cached pages
my $clear_cache = sub ($action, $c) {

  state $app   = $c->app;
  state $droot = $app->config('domove_root');
  my $id        = $c->param('id');
  my $cll       = $c->stash('controller');
  my $domain    = '';
  my $cache_dir = '';
  $c->debug("id:$id");

  #it is a page
  if ($cll =~ /stranici/i) {
    my $dom_id = $c->stranici->find($id)->{dom_id};
    $domain = $c->domove->find($dom_id)->{domain};
  }

  # it is a celina
  elsif ($cll =~ /celini/i) {
    my $page_id = $c->celini->find($id)->{page_id};
    my $dom_id  = $c->stranici->find($page_id)->{dom_id};
    $domain = $c->domove->find($dom_id)->{domain};
  }

  my $ok = $action->($c);
  return unless $ok;

  $cache_dir = path $droot, $domain, 'public', $cached;

  $c->debug('REMOVING ' . $cache_dir);
  $cache_dir->remove_tree;
  return $ok;
};

around update => $clear_cache;
around remove => $clear_cache;

1;

