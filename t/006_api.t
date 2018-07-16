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

subtest 'api/stranici' => sub {
  $t->get_ok("/api/страници")->status_is(200)->json_is('/0/alias' => 'писания');

  #create several pages and then check the list again
  ok($t->login('краси', 'беров') => 'login ok');
  my $sform = {
               page_type   => 'обичайна',
               permissions => 'drwxr-xr-x',
               published   => 2,
               title       => 'Събития',
               body     => 'Някaкъв по-дълъг теѯт, който е тяло на писанѥто.',
               language => 'bg-bg'
              };
  my $stranici_url     = $app->url_for('store_stranici')->to_string;
  my $pid              = 9;
  my $stranici_url_new = "$stranici_url/$pid";
  $t->ua->post($stranici_url => form => $sform);
  $t->get_ok($stranici_url_new)->status_is(200)->content_like(qr/събития/);
  @$sform{qw(permissions pid)} = ('-rwxr-xr-x', $pid);
  my $id = $pid;

  for my $title (qw(Foo Bar Baz)) {
    $sform->{title} = $title;
    $t->ua->post($stranici_url => form => $sform);
    $id++;
    $t->get_ok("$stranici_url/$id/edit?language=bg-bg")->status_is(200)
      ->content_like(qr/$title/);
  }
  $t->ua->get('/изходъ');    # logout
  $t->get_ok("/api/страници?pid=$pid")->status_is(200)
    ->json_is('/0/alias' => 'foo')->json_is('/2/alias' => 'baz');
};

done_testing;

