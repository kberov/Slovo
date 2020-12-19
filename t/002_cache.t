use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More;
use Slovo::Cache;

subtest 'Basics' => sub {
  my $cache = Slovo::Cache->new(max_keys => 2);
  is $cache->get('foo'), undef, 'no result';
  $cache->set(foo => 'bar');
  is $cache->get('foo'), 'bar', 'right result';
  $cache->set(bar => 'baz');
  is $cache->get('foo'), 'bar', 'right result';
  is $cache->get('bar'), 'baz', 'right result';
  $cache->set(baz => 'yada');
  is $cache->get('foo'), undef,  'no result';
  is $cache->get('bar'), 'baz',  'right result';
  is $cache->get('baz'), 'yada', 'right result';
  $cache->set(yada => 23);
  is $cache->get('foo'),  undef,  'no result';
  is $cache->get('bar'),  undef,  'no result';
  is $cache->get('baz'),  'yada', 'right result';
  is $cache->get('yada'), 23,     'right result';
  $cache->max_keys(1)->set(one => 1)->set(two => 2);
  is $cache->get('one'), undef, 'no result';
  is $cache->get('two'), 2,     'right result';
};

subtest 'Bigger cache' => sub {
  my $cache = Slovo::Cache->new(max_keys => 3);
  is $cache->get('foo'), undef, 'no result';
  is $cache->set(foo => 'bar')->get('foo'), 'bar', 'right result';
  $cache->set(bar => 'baz');
  is $cache->get('foo'), 'bar', 'right result';
  is $cache->get('bar'), 'baz', 'right result';
  $cache->set(baz => 'yada');
  is $cache->get('foo'), 'bar',  'right result';
  is $cache->get('bar'), 'baz',  'right result';
  is $cache->get('baz'), 'yada', 'right result';
  $cache->set(yada => 23);
  is $cache->get('foo'),  undef,  'no result';
  is $cache->get('bar'),  'baz',  'right result';
  is $cache->get('baz'),  'yada', 'right result';
  is $cache->get('yada'), 23,     'right result';
};

subtest 'Cache disabled' => sub {
  my $cache = Slovo::Cache->new(max_keys => 0);
  is $cache->get('foo'), undef, 'no result';
  is $cache->set(foo => 'bar')->get('foo'), undef, 'no result';

  $cache = Slovo::Cache->new(max_keys => -1);
  is $cache->get('foo'), undef, 'no result';
  $cache->set(foo => 'bar');
  is $cache->get('foo'), undef, 'no result';
};

subtest 'Key prefix' => sub {
  my $templates = {
    '/partials/_foo.html.ep' => bless({foo => 1}, __PACKAGE__),
    'bar.html.ep'            => bless({foo => 2}, __PACKAGE__),
  };

  my $c1 = Slovo::Cache->new();
  isa_ok($c1 => 'Slovo::Cache');
  isa_ok($c1 => 'Mojo::Cache');
  is($c1->max_keys   => 111 => 'default max keys');
  is($c1->key_prefix => ''  => 'default key_prefix');
  for (keys %$templates) {
    $c1->set($_ => $templates->{$_});
    ok($c1->get($_) => $_ . ' without prefix');
  }

  my $c2 = Slovo::Cache->new(key_prefix => '-');
  for (keys %$templates) {
    $c2->set($_ => bless({foo => 3}, __PACKAGE__));
    ok($c2->get($_) => $_ . ' with prefix');
  }

  # Keys with different prefix in the same object
  $c2->key_prefix('a');

  for (keys %$templates) {
    $c2->set($_ => bless({foo => 4}, __PACKAGE__));
    ok($c2->get($_) => $_ . ' with new prefix');
  }
  is(keys %{$c2->cache} => 4, 'more keys');
};

done_testing();
