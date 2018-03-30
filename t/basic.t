use Mojo::Base -strict;

BEGIN {
  binmode STDOUT => ':utf8';
  binmode STDERR => ':utf8';
}
use Test::More;
use Test::Mojo;
my $t   = Test::Mojo->new('Slovo');
my $app = $t->app;
is(
   $Slovo::CODENAME => 'U+2C0B GLAGOLITIC CAPITAL LETTER I (Ⰻ)',
   $Slovo::CODENAME
  ),
  is($app->config('db_foo'), 'чудесно!', 'database configuration is loaded');
isa_ok($app->dbx => 'Mojo::SQLite');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

done_testing();
