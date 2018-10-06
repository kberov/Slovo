use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
use Mojo::Util qw(slugify encode);
use Mojo::Loader qw(data_section);
use Mojo::Collection 'c';
my $t = Test::Mojo->with_roles('+Slovo')->install(

  '.' => '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;

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
  $t->login('краси', 'беров');
  my $alias = b('писания.bg-bg.html')->encode->url_escape;
  my $vest_alias
    = '/'
    . b('вести')->encode->url_escape . '/'
    . b('първа-вест.bg-bg.html')->encode->url_escape;
  $t->get_ok('/вести.html')
    ->element_exists(qq|td.mui--text-title > a[href="/$alias"]|)
    ->element_exists(
             'main section.заглавѥ article.писанѥ:nth-child(2) h2:nth-child(1)')
    ->text_is(  'section.заглавѥ.множество article.писанѥ:nth-child(3)'
              . '>h2:nth-child(1)>a:nth-child(1)' => 'Вътора вест')
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
  unlike($body => qr/<html[^>]+><!-- $cached -->/ =>
         'Root page with path / is not cached');

  # Page with alias as name is cached
  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html[^>]+><!-- $cached -->/ =>
         'On first load page with path /foo.html IS NOT cached');
  $body = $t->get_ok("/коренъ.html")->status_is(200)->tx->res->body;
  like($body => qr/<html[^>]+><!-- $cached -->/ =>
       'On second load page with path /foo.html IS cached');
  ok(-s $cache_dir->child('коренъ.html'), 'and file is on disk');
  ok(!-f $cache_dir->child('коренъ.bg.html'),
     ' /foo.bg.html IS NOT YET cached');
  $t->get_ok("/коренъ.bg.html");    #
  $body = $t->get_ok("/коренъ.bg.html")->status_is(200)->tx->res->body;
  like($body => qr/<html[^>]+><!-- $cached -->/ =>
       'Page with alias and language is cached');
  ok(!-f $cache_dir->child('вести/вътора-вест.bg.html'),
     ' /foo/bar.bg.html IS NOT YET on disk');
  $body
    = $t->get_ok("/вести/вътора-вест.bg.html")->status_is(200)->tx->res->body;
  unlike($body => qr/<html[^>]+><!-- $cached -->/ =>
         'On first celina with path /foo/bar.bg.html was just cached');

  $body
    = $t->get_ok("/вести/вътора-вест.bg.html")->status_is(200)->tx->res->body;
  like($body => qr/<html[^>]+><!-- $cached -->/ => 'celina is cached');

  $t->login('краси', 'беров');

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

  for my $p (@cats) {
    my $id = 'section#страница-' . $pages->{$p}{id};
    $t->element_exists($id)->element_count_is($id . ' article.писанѥ', 6);
    $t->element_exists(
              $id . ' article h2 a[title^="' . substr($_->{title}, 0, 5) . '"]')
      for @{$pages->{$p}{articles}}[0 .. 5];
  }
};

sub _category_page {
  my ($p, $pages) = @_;
  my $body
    = c(split /[,.\n]?\s+/, lc data_section('Slovo::Test::Text', 'text.txt'))
    ->shuffle->slice(0 .. 50)->join(' ');
  $pages->{$p}{id} = $app->stranici->add(
                                         {
                                          title       => ucfirst($p),
                                          language    => 'bg',
                                          body        => "<p>$body</p>",
                                          data_format => 'html',
                                          tstamp      => time,
                                          user_id     => 5,
                                          group_id    => 5,
                                          changed_by  => 5,
                                          alias       => slugify($p, 1),
                                          permissions => 'drwxr-xr-x',
                                          published   => 2,
                                          page_type   => 'обичайна',
                                          dom_id      => 0,
                                         }
                                        );
  _pisania($p, $pages);
  _sub_pages($p, $pages);
  ok(1 => 'generated full set of data for category ' . encode('utf8', $p));
}

sub _sub_pages {
  my ($p, $pages) = @_;
  my $sub_pages = {};
  for my $sp (qw(днесъ вчера оня-ден)) {
    $sub_pages->{$sp} =
      $app->stranici->add(
                          {
                           title       => ucfirst($sp),
                           language    => 'bg',
                           body        => "",
                           data_format => 'html',
                           tstamp      => time,
                           user_id     => 5,
                           group_id    => 5,
                           changed_by  => 5,
                           alias       => slugify("$p-$sp", 1),
                           permissions => 'rwxr-xr-x',
                           published   => 2,
                           page_type   => 'обичайна',
                           dom_id      => 0,
                           pid         => $pages->{$p}{id}
                          }
                         );
  }
}

sub _pisania {
  my ($p, $pages) = @_;

  my $in = {};
  @$in{qw(user_id group_id changed_by created_at)} = (5, 5, 5, time - 1);
  my $pid = $app->celini->find_where(
                   {page_id => $pages->{$p}{id}, data_type => 'заглавѥ'})->{id};
  my $cels = int(rand(50));
  $pages->{$p}{articles} = [];
  my $data = lc data_section('Slovo::Test::Text', 'text.txt');
  for my $cel (0 .. ($cels < 10 ? 10 : $cels)) {

    #create dummy body
    my $body = c(split /[,.\n]?\s+/, $data)->shuffle->join(' ');
    my $tlength = int rand(100);
    $tlength < 20 && ($tlength = 20);

    # Add some dummy markup for tests
    $body = "<p>$body</p>";
    $body =~ s/^(<p>\w+\s+)(\w+)/$1<b>$2<img src="a.jpg"><\/b>/;
    $body = $body x (int rand(5) < 2 || 2);
    my ($title) = $body =~ /^(.{0,$tlength})/;

    my $cid = $app->celini->add(
                                {
                                 %$in,
                                 language    => 'bg',
                                 page_id     => $pages->{$p}{id},
                                 pid         => $pid,
                                 data_format => 'html',
                                 data_type   => 'писанѥ',
                                 title       => ucfirst $title,
                                 alias       => slugify("$title $cel $p", 1),
                                 body        => $body,
                                 permissions => 'rwxr-xr-x',
                                 published   => 2,
                                }
                               );
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
  my $page = $app->stranici->find_where(
                {published => 2, deleted => 0, hidden => 0, id => {'>' => 16}});
  my $new_alias;
  for my $a ('A' .. 'F') {
    $new_alias = $page->{alias} . $a;
    $app->stranici->save($page->{id}, {%$page, alias => $new_alias});
  }

  my $new_url = b("$new_alias.bg-bg.html")->encode->url_escape;
  for my $a ('', 'A' .. 'E') {
    my $alias = b("$page->{alias}$a.bg-bg.html")->encode->url_escape;
    $t->get_ok("/$alias")->status_is(301)
      ->header_like(Location => qr/$new_url/);
  }

  my $dom = $t->get_ok("/$new_url")->status_is(200)->tx->res->dom;
  like $dom->at('head>link[rel="canonical"]')->attr->{href}, qr/$new_url/,
    '[rel="canonical"] ok';
  is $dom->at('head>link[rel="shortcut icon"]')->attr->{href},
    '/img/favicon.ico', '[rel="shortcut icon"] ok';
};


subtest 'Not Found'       => $not_found;
subtest 'previewed pages' => $previewed_pages;
subtest 'site layout'     => $site_layout;
subtest breadcrumb        => $breadcrumb;

# Disabled untill proper test cases are prepared
# subtest multi_language_pages => $multi_language_pages;
subtest cached_pages => $cached_pages;
subtest home_page    => $home_page;
subtest aliases      => $aliases;
done_testing;

package Slovo::Test::Text;

__DATA__
@@ text.txt
Да се познават случилите се по-рано в тоя
свят неща и делата на ония, които са живеели на земята, е не само полезно, но и
твърде потребно, любомъдри читателю. Ако навикнеш да прочиташ често тия неща,
ще се обогатиш с разум, не ще бъдеш много неизкусен и ще отговаряш на малките
деца и простите хора, когато при случай те запитат за станалите по-рано в света
деяния от черковната и гражданска история. И не по-малко ще се срамуваш, когато
не можеш да отговориш за тях.

Отгде ще можеш да добиеш тия знания, ако не от ония, които писаха историята
на този свят и които при все че не са живели дълго време, защото никому не се
дарява дълъг живот, за дълго време оставиха писания за тия неща. Сами от себе
си да се научим не можем, защото кратки са дните на нашия живот на земята.
Затова с четене на старите летописи и с чуждото умение трябва да попълним
недостатъчността на нашите години за обогатяване на разума.

Искаш ли да седиш у дома си и да узнаеш без много трудно и опасно пътуване
миналото на всички царства на тоя свят и ставащите сега събития в тях и да
употребиш тия знания за умна наслада и полза за себе си и за другите, чети
историята! Искаш ли да видиш като на театър играта на тоя свят, промяната и
гибелта на големи царства и царе и непостоянството на тяхното благополучие, как
господстващите и гордеещите се между народите племена, силни и непобедими в
битките, славни и почитани от всички, внезапно отслабваха, смиряваха се,
упадаха, загиваха, изчезваха - чети историята и като познаеш от нея суетата на
този свят, научи се да го презираш. Историята дава разум не само на всеки
човек, за да управлява себе си или своя дом, но и на големите владетели за
добро властвуване: как могат да държат дадените им от бога поданици в страх
божи, в послушание, тишина, правда и благочестие, как да укротяват и
изкореняват бунтовниците, как да се опълчват против външните врагове във
войните, как да ги победят и сключат мир. Виж колко голяма е ползата от
историята. Накратко това е заявил Василий, источният кесар, на своя син Лъв
Премъдри. Съветайки го, каза: „Не преставай - рече - да четеш историята на
древните. Защото там без труд ще намериш онова, за което други много са се
трудили. От тях ще узнаеш добродетелите на добрите и законопрестъпленията на
злите, ще познаеш превратностите на човешкия живот и обратите на благополучието
в него, и непостоянството в този свят, и как и велики държави клонят към
падение. Ще размислииш и ще видиш наказанието на злите и наградата на добрите.
От тях се пази!”
