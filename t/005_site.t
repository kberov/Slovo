use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
my $t = Test::Mojo->with_roles('+Slovo')->install(

# '.', '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;

subtest 'Not Found' => sub {
  for my $alias (qw(скрита изтрита предстояща изтекла несъществуваща)) {
    $t->get_ok("/$alias.html")->status_is(404);
  }
};

$t->login_ok('краси', 'беров');

subtest 'previewed pages' => sub {
  for my $alias (qw(скрита изтрита предстояща изтекла)) {
    $t->get_ok("/$alias.html?прегледъ=1")->status_is(200);
  }
};

subtest 'site layout' => sub {
  $t->get_ok($app->url_for('sign_out'))->status_is(302)
    ->header_is('Location' => '/');
  $t->get_ok("/коренъ.html")->status_is(200)
    ->element_exists('body header.mui-appbar')
    ->element_exists('aside#sidedrawer')
    ->element_exists('main#content-wrapper')
    ->element_exists('footer.mui-appbar');
  $t->get_ok('/ѿносно.html')->status_is(200)

    #   ->element_exists_not('aside#sidedrawer');
    # menu item in sidedrawer
    ->element_exists('#sidedrawer ul li div');

};

subtest breadcrumb => sub {
  $t->login_ok('краси', 'беров');
  my $alias = b('писания.bg-bg.html')->encode->url_escape;
  my $vest_alias
    = '/'
    . b('вести')->encode->url_escape . '/'
    . b('първа-вест.bg-bg.html')->encode->url_escape;
  $t->get_ok('/вести.html')
    ->element_exists(qq|td.mui--text-title > a[href="/$alias"]|)
    ->element_exists(
             'main section.заглавѥ section.писанѥ:nth-child(2) h2:nth-child(1)')
    ->text_is('section.писанѥ:nth-child(3) > h2:nth-child(1)' => 'Вътора вест')
    ->element_exists(qq|a[href="$vest_alias"]|);
  $t->get_ok($vest_alias)->text_is('main section h1' => 'Първа вест');
  $t->get_ok('/вести/alabala.html')->status_is(404)
    ->text_is('.заглавѥ > h1:nth-child(1)' => 'Страницата не е намерена')
    ->text_is('aside#sidedrawer>ul>li>strong>a[href$="bg-bg.html"]' => 'Вести');
};

subtest multi_language_pages => sub {
  $t->get_ok('/вести/alabala.html')->status_is(404)
    ->text_like('.mui-dropdown > button' => qr'bg-bg')
    ->element_exists_not(
                      '.mui-dropdown__menu > li:nth-child(2) > a:nth-child(1)');
  my $dom
    = $t->get_ok("/")->text_like('.mui-dropdown > button' => qr'bg')
    ->element_exists('.mui-dropdown__menu > li:nth-child(2) > a:nth-child(1)')
    ->tx->res->dom;

  # warn $dom->at('.mui-dropdown__menu');
};

done_testing;

