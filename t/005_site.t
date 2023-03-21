use Mojo::Base -strict, -signatures;
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
use Mojo::Util   qw(slugify encode decode sha1_sum);
use Mojo::Loader qw(data_section);
use Mojo::Collection 'c';
my $t = Test::Mojo->with_roles('+Slovo')->install(

#  undef() => '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;

# like in production
$app->config->{cache_pages} = 1;
my $not_found = sub {
  for my $alias (qw(скрита изтрита предстояща изтекла несъществуваща)) {
    $t->get_ok("/$alias.html")->status_is(404);
  }
};
$t->login('краси', 'беров');
my $previewed_pages = sub {
  for my $alias (qw(скрита изтрита предстояща изтекла)) {
    $t->get_ok("/$alias.html?прегледъ=1")->status_is(200);
  }
};

my $site_layout = sub {
  $t->get_ok($app->url_for('sign_out'))->status_is(302)
    ->header_is('Location' => $app->url_for('authform'));
  $t->get_ok("/коренъ.html")->status_is(200)->element_exists('body > header nav')
    ->element_exists('header>nav>a>#logo')->element_exists('main.container')
    ->element_exists('footer');
  $t->get_ok('/ѿносно.html')->status_is(200)

    ->element_exists('header>nav');

  $t->meta_names_ok();
};

my $breadcrumb = sub {
  $t->login('краси', 'беров');
  my $alias = b('писания.bg-bg.html')->encode->url_escape;
  my $vest_alias
    = '/'
    . b('вести')->encode->url_escape . '/'
    . b('първа-вест.bg-bg.html')->encode->url_escape;

  $t->get_ok('/вести.html')->element_exists(qq|header > nav > a[href="/$alias"]|)
    ->element_exists('main section.row>.card.col-12')
    ->text_is('main section.row>.card.col-12>header>h4>a' => 'Вътора вест')
    ->element_exists(qq|a[href="$vest_alias"]|);
  $t->get_ok($vest_alias)->text_is('main section h1' => 'Първа вест');
  $t->get_ok('/вести/alabala.html')->status_is(404)
    ->text_is('main.container > h1:nth-child(1)' => 'Страницата не е намерена');
};

my $multi_language_pages = sub {
  $t->get_ok('/вести/alabala.html')->status_is(404)->element_exists('html[lang="bg-bg"]');

# TODO: Review language switching.
#  my $dom
#    = $t->get_ok("/")->text_like('.mui-dropdown > button' => qr'bg')
#    ->element_exists('.mui-dropdown__menu > li:nth-child(2) > a:nth-child(1)')
#    ->tx->res->dom;
#  warn $dom->at('.mui-dropdown__menu');
};

my $cached_pages = sub {
  Mojo::File->import('path');

  # Clear any cache
  my $cached    = 'cached';
  my $cache_dir = path($app->config('domove_root'), 'localhost', 'public', $cached);
  ok($cache_dir->remove_tree => 'clear cache');
  $t->get_ok($app->url_for('sign_out'));

  # Root page with path / is not cached
  $t->get_ok("/")->status_is(200);
  my $body = $t->get_ok("/")->status_is(200)->tx->res->body;
  like(decode('UTF-8', $body) => qr/rel="canonical" href=".+?коренъ\.bg-bg\.html"/ =>
      '... and shows its canonical url.');

  # Page with alias as name is cached AS IS
  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  like(decode('UTF-8', $body) => qr/rel="canonical" href=".+?\/коренъ\.bg-bg\.html"/ =>
      '... and shows its canonical url.');

  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  ok(-s $cache_dir->child(sha1_sum(encode('UTF-8' => '/коренъ.html')) . '.html'),
    'and file is on disk');
  ok(!-f $cache_dir->child('коренъ.bg.html'), ' /foo.bg.html IS NOT cached');

  $t->get_ok("/коренъ.bg-bg.html");
  $body = $t->get_ok("/коренъ.bg-bg.html")->status_is(200)->tx->res->body;

  ok(!-f $cache_dir->child('вести/вътора-вест.bg.html'),
    ' /foo/bar.bg.html IS NOT YET on disk');

  $body = $t->get_ok("/вести/вътора-вест.bg.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html[^>]+><!-- $cached -->/ =>
      'On first request celina with path /foo/bar.bg.html was just cached');

  $body = $t->get_ok("/вести/вътора-вест.bg-bg.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html[^>]+><!-- $cached -->/ =>
      'celina with canonical name is cached for next requests');
  ok(!-f $cache_dir->child('вести/вътора-вест.bg.html'),
    '/foo/bar.bg.html IS NOT cached');

  $t->login('краси', 'беров');

  # Cache is cleared when editing or deleting a page or writing
  my $id
    = $app->dbx->db->query("SELECT id FROM celini WHERE alias='вътора-вест'")->hash->{id};

  $t->delete_ok('/manage/celini/' . $id)->status_is(302);
  ok(!-f $cache_dir->child('вести/вътора-вест.bg-bg.html'),
    '/foo/bar.bg.html IS NOT anymore on disk');
  ok(!-d $cache_dir->child('вести'), '/foo IS NOT anymore on disk');
  ok(!-e $cache_dir,                 '$cache_dir IS NOT anymore on disk');
};

my $browser_cache = sub {
  $t->get_ok($app->url_for('sign_out'));

  # file cached on disk and served by $c->reply->file
  my $headers = $t->get_ok("/вести.bg-bg.html")->status_is(200)->tx->res->headers;

  # this is not cannonical url, we serve it dynamically and provide only
  # Last-Modified header
  $t->get_ok("/вести.bg.html" =>
      {'If-Modified-Since' => $headers->last_modified, 'If-None-Match' => $headers->etag})
    ->status_is(304);
  $t->get_ok("/вести.bg.html" => {'If-None-Match' => $headers->etag})->status_is(200);
  $t->header_is('Cache-Control' => $app->config('cache_control'));

  # this is cannonical
  $headers = $t->get_ok("/вести.bg-bg.html")->status_is(200)->tx->res->headers;
  $t->get_ok("/вести.bg-bg.html" => {'If-None-Match' => $headers->etag})->status_is(304);

  # Browser cache for signed in users
  $t->login('краси', 'беров');
  my $tstamp
    = $app->dbx->db->select('stranici', 'tstamp', {alias => 'вести'})->hash->{tstamp};

  my $date = Mojo::Date->new($tstamp);
  my $etag = Mojo::Util::md5_sum($date->epoch);

  $headers = $t->get_ok("/вести.bg-bg.html")->status_is(200)->tx->res->headers;

  $t->header_is('Cache-Control' => $app->config('cache_control') =~ s/public/private/r);
  $t->get_ok("/вести.bg-bg.html" => {'If-None-Match' => $etag})->status_is(200);

  $t->get_ok("/вести.bg-bg.html" => {'If-Modified-Since' => "$date"})->status_is(304);
  $t->get_ok("/вести.bg-bg.html" => {'If-Modified-Since' => "$date"})->status_is(304);
};


# Generate and test a fullblown home page with several sections consisting of
# content in category pages.
my @cats      = qw(време нрави днесъ сѫд въпроси сбирка бележки техника наука);
my $home_page = sub {

  #create category pages
  my $pages = {};
  for my $p (@cats) {
    _category_page($p, $pages);
  }
  ok(keys %$pages => 'generated data');

  # use the new template
  $app->stranici->save(0 => {template => 'stranici/templates/dom'});
  $t->get_ok('/')->status_is(200);

  # my $body = $t->tx->res->body;
  # note $body;
  # return;
  for my $p (@cats) {
    my $id = '#page-' . $pages->{$p}{id};

    $t->element_exists($id, $id . ' exists in page ');
    $t->element_exists($id . ' a[title^="' . ucfirst(substr($p, 0, 5) . '"]'),
      'link with title ' . $p);
  }
  $t->meta_names_ok();
};

sub _meta_keywords_description ($text) {
  my %meta = ();
  $meta{keywords}
    = c($text =~ /(\w+)/g)->shuffle->head(int rand 20)->join(',')->to_string;
  my $descr = c(split /[\n\n]/, $text)->shuffle->head(1)->[0];
  ($meta{description}) = $text = substr($descr, 0, int rand 100);
  return %meta;
}

sub _category_page {
  my ($p, $pages) = @_;
  my $text = data_section('Slovo::Test::Text', 'text.txt');
  my $body = c(split /[\n\n]/, $text)->shuffle->head(3)->join('</p><p>');

  $pages->{$p}{id} = $app->stranici->add({
    title       => ucfirst($p),
    language    => 'bg',
    body        => "<p>$body</p>",
    data_format => 'html',
    user_id     => 5,
    group_id    => 5,
    changed_by  => 5,
    alias       => slugify($p, 1),
    permissions => 'drwxrwxr-x',
    published   => 2,
    page_type   => 'regular',
    dom_id      => 0,
    _meta_keywords_description($text),
  });
  note "created page '$p' with id  $pages->{$p}{id}";
  _pisania($p, $pages);
  _sub_pages($p, $pages);
  ok(1 => 'generated full set of data for category ' . encode('utf8', $p));
}

sub _sub_pages {
  my ($p, $pages) = @_;
  my $sub_pages = {};
  my $text      = data_section('Slovo::Test::Text', 'text.txt');
  for my $sp (qw(днесъ вчера оня-ден)) {
    my $body = c(split /[\n\n]/, $text)->shuffle->head(2)->join('</p><p>');
    $sub_pages->{$sp} = $app->stranici->add({
      title       => ucfirst($sp),
      language    => 'bg',
      body        => "<p>$body</p>",
      data_format => 'html',
      tstamp      => time,
      user_id     => 5,
      group_id    => 5,
      changed_by  => 5,
      alias       => slugify("$p-$sp", 1),
      permissions => 'rwxr-xr-x',
      published   => 2,
      page_type   => 'regular',
      dom_id      => 0,
      pid         => $pages->{$p}{id},
      _meta_keywords_description($text),
    });
  }
}

sub _pisania {
  my ($p, $pages) = @_;

  my $in = {};
  @$in{qw(user_id group_id changed_by created_at)} = (5, 5, 5, time - 1);
  my $pid
    = $app->celini->find_where({page_id => $pages->{$p}{id}, data_type => 'title'})->{id};
  my $cels = int(rand(50));
  $pages->{$p}{articles} = [];
  my $data = data_section('Slovo::Test::Text', 'text.txt');
  for my $cel (0 .. ($cels < 10 ? 10 : $cels)) {

    #create dummy body
    my $body    = c(split /\n\n/, $data)->shuffle->join('</p><p>');
    my $tlength = int rand(100);
    $tlength < 20 && ($tlength = 20);

    # Add some dummy markup for tests
    $body = "<p>$body</p>";
    $body =~ s/^(<p>\w+\s+)(\w+)/$1<b>$2<img src="a.jpg"><\/b>/;
    $body = $body x (int rand(5) < 2 || 2);
    my ($title) = $body =~ /^(.{0,$tlength})/;

    my $cid = $app->celini->add({
      %$in,
      language    => 'bg',
      page_id     => $pages->{$p}{id},
      pid         => $pid,
      data_format => 'html',
      data_type   => 'writing',
      title       => ucfirst $title,
      alias       => slugify("$title $cel $p", 1),
      body        => $body,
      permissions => 'rwxr-xr-x',
      published   => 2,
      _meta_keywords_description($data),
    });
    push @{$pages->{$p}{articles}},
      {
      alias => slugify("$title $cel $p", 1),
      title => ucfirst($title) =~ s/<[^>]+>?//gr,
      id    => $cid
      };
  }
}

my $aliases = sub {

  # Get a newly created page and change the alias several times, then make
  # requests to see if the same page is displayed.
  my $page = $app->stranici->find_for_edit({'>' => 16}, 'bg');
  my $new_alias;
  for my $a ('A' .. 'F') {
    $new_alias = $page->{alias} . $a;
    $app->stranici->save($page->{id}, {%$page, alias => $new_alias});
  }

  my $new_url = b("$new_alias.bg-bg.html")->encode->url_escape;
  for my $a ('', 'A' .. 'E') {
    my $alias = b("$page->{alias}$a.bg-bg.html")->encode->url_escape;
    $t->get_ok("/$alias")->status_is(301)->header_like(Location => qr/$new_url/);
  }

  my $dom = $t->get_ok("/$new_url")->status_is(200)->tx->res->dom;
  like $dom->at('head>link[rel="canonical"]')->attr->{href}, qr/$new_alias/,
    '[rel="canonical"] ok';
  is $dom->at('head>link[rel="shortcut icon"]')->attr->{href}, '/img/favicon.ico',
    '[rel="shortcut icon"] ok';
};


subtest 'Not Found'       => $not_found;
subtest 'previewed pages' => $previewed_pages;
subtest 'site layout'     => $site_layout;
subtest breadcrumb        => $breadcrumb;

subtest multi_language_pages => $multi_language_pages;
subtest cached_pages         => $cached_pages;

subtest 'Browser cache' => $browser_cache;
subtest home_page       => $home_page;
subtest aliases         => $aliases;

done_testing;


package Slovo::Test::Text;

__DATA__
@@ text.txt
Да се познават случилите се по-рано в тоя свят неща и делата на ония, които са
живеели на земята, е не само полезно, но и твърде потребно, любомъдри читателю.

Ако навикнеш да прочиташ често тия неща, ще се обогатиш с разум, не ще бъдеш
много неизкусен и ще отговаряш на малките деца и простите хора, когато при
случай те запитат за станалите по-рано в света деяния от черковната и
гражданска история. И не по-малко ще се срамуваш, когато не можеш да отговориш
за тях.

Отгде ще можеш да добиеш тия знания, ако не от ония, които писаха историята
на този свят и които при все че не са живели дълго време, защото никому не се
дарява дълъг живот, за дълго време оставиха писания за тия неща. Сами от себе
си да се научим не можем, защото кратки са дните на нашия живот на земята.

