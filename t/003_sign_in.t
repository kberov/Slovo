use Mojo::Base -strict;
use FindBin;
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->with_roles('+Slovo')->install(

#  undef, '/tmp/slovo_sign_in'
)->new('Slovo');
isa_ok($t->app, 'Slovo');

$t->login_ok('краси', 'беров');

# TODO: Depending on the user and to where he headed redirect him after login
# to eventually ->text_is('head title' => 'manage');

done_testing;
