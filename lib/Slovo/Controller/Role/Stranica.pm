package Slovo::Controller::Role::Stranica;
use Mojo::Base -role, -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

around execute => sub ($execute, $c) {
  my $alias   = $c->stash->{'страница'};
  my $l       = $c->language;
  my $preview = $c->is_user_authenticated && $c->param('прегледъ');
  my $user    = $c->user;
  state $json_path      = '/paths/~1страници/get/parameters/4/default';
  state $list_columns   = $c->openapi_spec($json_path);
  state $not_found_id   = $c->not_found_id;
  state $not_found_code = $c->not_found_code;

  my $str = $c->stranici;
  my $page = $str->find_for_display($alias, $user, $c->domain, $preview);
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

  #TODO: do something after render, like caching for example
  return $ok;
};


1;

