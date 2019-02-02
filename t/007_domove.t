use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
use Mojo::Collection 'c';
my $test_class = Test::Mojo->with_roles('+Slovo');
unless ($ENV{TEST_DOMAIN}) {
  plan(
    skip_all => qq|Advanced test. Do the following to run this test.
     \$ export TEST_DOMAIN="${\ $test_class->domain_aliases}"
     \$ sudo vim /etc/hosts and add the following domains to 127.0.0.1
     bg.localhost en.localhost ${\ $test_class->domain_aliases}
     Then run this test again.
     |
  );
}

my $t = $test_class->install(

# '.', '/tmp/slovo'
)->new('Slovo');

my $app = $t->app;

#make краси admin:
$t->app->dbx->db->insert("user_group" => {user_id => 5, group_id => 1});

subtest create_domain_and_page => sub {
  my ($dom_id) = $t->create_edit_domain_ok() =~ /(\d+)$/;
  my $form = {
    alias       => 'коренъ',
    title       => 'Добре дошли!',
    page_type   => 'коренъ',
    body        => 'Добре сте ни дошли на този сайт.',
    language    => 'bg-bg',
    published   => 2,
    permissions => '-rwxr-xr-x',
    dom_id      => $dom_id,
    data_format => 'text',
  };

  # TODO: add negative test. Implement validation check against adding
  # anodher root page in the same domain.
  $t->post_ok($app->url_for('store_stranici') => form => $form)->status_is(302);
};

subtest visit_domains => sub {

  #logout
  $t->get_ok($app->url_for('sign_out'))->status_is(302);

  # visit first two domains' root pages
  my $domove = $app->domove->all({limit => 2});
  $domove->each(sub {
    my $d       = shift;
    my @aliases = $d->{domain};
    push @aliases, split /\s+/, $d->{aliases};
    my $page = $app->dbx->db->select(
      ['stranici', 'celini'],
      ['title',    'body'],
      {
        'dom_id'         => $d->{id},
        'data_type'      => 'заглавѥ',
        'celini.page_id' => {-ident => 'stranici.id'}})->hashes->[0];
    for my $alias (@{c(@aliases)->uniq}) {
      my $url = $t->ua->server->nb_url->host($alias);
      $t->get_ok($url)->status_is(200)->text_is('head > title' => $page->{title})
        ->text_like('body section.заглавѥ' => qr/$page->{body}/);
    }
  });
};

done_testing();

