use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->with_roles('+Slovo')->install()->new('Slovo');
isa_ok($t->app, 'Slovo');
$t->login_ok('краси', 'беров');

# TODO: ->text_is('head title' => 'Ꙋправленѥ');

done_testing;

