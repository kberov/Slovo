use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
my $t = Test::Mojo->with_roles('+Slovo')->install()->new('Slovo');
$t->get_ok('/')->status_is(200)->content_like(qr/Слово/i);

done_testing();
