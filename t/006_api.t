use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
my $t = Test::Mojo->with_roles('+Slovo')->install(

#  '.', '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;

subtest 'api/stranici' => sub {
  $t->get_ok("/api/stranici")->status_is(200)->json_is('/0/alias' => 'писания');

  #create several pages and then check the list again
  ok($t->login('краси', 'беров') => 'login ok');
  my $sform = {
    page_type   => 'regular',
    permissions => 'drwxr-xr-x',
    published   => 2,
    title       => 'Събития',
    body        => 'Някaкъв по-дълъг теѯт, който е тяло на писанѥто.',
    language    => 'bg-bg',
    data_format => 'text',
    pid         => 0,
  };
  my $stranici_url     = $app->url_for('store_stranici')->to_string;
  my $pid              = 9;
  my $stranici_url_new = $app->url_for('edit_stranici', id => $pid)->to_string;
  $t->post_ok($stranici_url => form => $sform)->status_is(302);
  $t->get_ok("/api/stranici")->status_is(200)->json_is('/2/alias' => 'събития');
  $t->get_ok("/api/stranici?columns=id,alias,title")->json_is('/2/id' => $pid);

  # See lib/Slovo/resources/api-v1.0.json StraniciItem.required
  $t->get_ok("/api/stranici?columns=id,alias")->status_is(500);
  $t->json_is('/errors/2' => {message => 'Missing property.', path => '/body/2/title'});

  # note explain $t->tx->res->json;
  $t->get_ok("/api/stranici?columns=id,alias,title")->status_is(200)
    ->json_is('/2' => {id => $pid, alias => 'събития', title => 'Събития'});


  @$sform{qw(permissions pid)} = ('-rwxr-xr-x', $pid);
  my $id = $pid;

  for my $title (qw(Foo Bar Baz)) {
    $sform->{title} = $title;
    $t->ua->post($stranici_url => form => $sform);
    $id++;
    $t->get_ok("$stranici_url/$id/edit?language=bg-bg")->status_is(200)
      ->content_like(qr/$title/);
  }
  $t->ua->get('/out');    # logout
  $t->get_ok("/api/stranici?pid=$pid")->status_is(200)->json_is('/0/alias' => 'foo')
    ->json_is('/2/alias' => 'baz');
};

done_testing;
