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

my $not_found = sub {
  for my $alias (qw(скрита изтрита предстояща изтекла несъществуваща)) {
    $t->get_ok("/$alias.html")->status_is(404);
  }
};

$t->login_ok('краси', 'беров');
my $previewed_pages = sub {
  for my $alias (qw(скрита изтрита предстояща изтекла)) {
    $t->get_ok("/$alias.html?прегледъ=1")->status_is(200);
  }
};

my $site_layout = sub {
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

my $breadcrumb = sub {
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

my $multi_language_pages = sub {
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

my $cached_pages = sub {
  Mojo::File->import('path');

  #clear any cache
  my $cached = 'cached';
  my $cache_dir
    = path($app->config('domove_root'), 'localhost', 'public', $cached);
  ok($cache_dir->remove_tree => 'clear cache');
  $t->get_ok($app->url_for('sign_out'));

  # Root page with path / is not cached
  $t->get_ok("/")->status_is(200);
  my $body = $t->get_ok("/")->status_is(200)->tx->res->body;
  unlike($body => qr/<html><!-- $cached -->/ =>
         'Root page with path / is not cached');

  # Page with alias as name is cached
  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html><!-- $cached -->/ =>
         'On first load page with path /foo.html IS NOT cached');
  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  like($body => qr/<html><!-- $cached -->/ =>
       'On second load page with path /foo.html IS cached');
  ok(-s $cache_dir->child('коренъ.html'), 'and file is on disk');
  ok(!-f $cache_dir->child('коренъ.bg.html'),
     ' /foo.bg.html IS NOT YET cached');
  $t->get_ok("/коренъ.bg.html");    #
  $body = $t->get_ok("/коренъ.bg.html")->status_is(200)->tx->res->body;
  like($body => qr/<html><!-- $cached -->/ =>
       'Page with alias and language is cached');
  ok(!-f $cache_dir->child('вести/вътора-вест.bg.html'),
     ' /foo/bar.bg.html IS NOT YET on disk');
  $body
    = $t->get_ok("/вести/вътора-вест.bg.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html><!-- $cached -->/ =>
         'On first celina with path /foo/bar.bg.html was just cached');

  $body
    = $t->get_ok("/вести/вътора-вест.bg.html")->status_is(200)->tx->res->body;
  like($body => qr/<html><!-- $cached -->/ => 'celina is cached');

  $t->login_ok('краси', 'беров');

  # Cache is cleared when editing or deleting a page or писанѥ
  my $id
    = $app->dbx->db->query("SELECT id FROM celini WHERE alias='вътора-вест'")
    ->hash->{id};

  $t->delete_ok('/Ꙋправленѥ/celini/' . $id)->status_is(302);
  ok(!-f $cache_dir->child('вести/вътора-вест.bg.html'),
     '/foo/bar.bg.html IS NOT anymore on disk');
  ok(!-d $cache_dir->child('вести'), '/foo IS NOT anymore on disk');
  ok(!-e $cache_dir,                 '$cache_dir IS NOT anymore on disk');
};

subtest 'Not Found' => $not_found;
subtest 'previewed pages' => $previewed_pages;
subtest 'site layout' => $site_layout;
subtest breadcrumb => $breadcrumb;
subtest multi_language_pages => $multi_language_pages;
subtest cached_pages => $cached_pages;

done_testing;

