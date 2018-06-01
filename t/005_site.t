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
    $t->get_ok("/$alias.стр.html")->status_is(404);
  }
};

$t->login_ok('краси', 'беров');

subtest 'previewed pages' => sub {
  for my $alias (qw(скрита изтрита предстояща изтекла)) {
    $t->get_ok("/$alias.стр.html?прегледъ=1")->status_is(200);
  }
};


done_testing;
exit;
