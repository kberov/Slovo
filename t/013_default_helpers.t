use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use FindBin;
use Mojo::Util qw(punycode_encode);
use Mojo::Collection 'c';

use lib "$FindBin::Bin/lib";
my $t   = Test::Mojo->with_roles('+Slovo')->install()->new('Slovo');
my $app = $t->app;
my $c   = $app->build_controller;
$c->req->headers->host('xn--' . punycode_encode('алабала') . '.com:3000');
is $c->host_only             => 'xn--80aaaad2dd.com', 'right host';
is $c->ihost_only            => 'алабала.com',        'right ihost';
is $c->is_user_authenticated => '',                   'is_user_authenticated: no';
is $c->languages->first => c(@{$c->openapi_spec('/parameters/language/enum')})->first,
  'languages';
is $c->language                 => 'bg-bg', 'get right language';
is $c->language('sr')->language => 'sr',    'set right language';
is $c->language('ua')->language => $c->languages->first, 'set wrong language';
ok ref $app->renderer->helpers->{debug} eq 'CODE' => '$c->debug exists';

done_testing();
