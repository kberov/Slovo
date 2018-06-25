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
  $t->get_ok("/api/страници")->status_is(200)->json_is('/0/alias' => 'коренъ');
};

done_testing;

