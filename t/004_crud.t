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
isa_ok($app, 'Slovo');
$t->login_ok('краси', 'беров');

my $users_url  = $app->url_for('home_users')->to_string;
my $groups_url = $app->url_for('home_groups')->to_string;
my $user6_url  = $app->url_for('show_users', id => 6)->to_string;
$t->get_ok("$users_url/5")->status_is(200)
  ->text_is('body > p:nth-child(6)' => 'Краси');

# Disabled User
$t->get_ok("$users_url/0")->status_is(404);

# Disabled group
$t->get_ok("$groups_url/0")->status_is(404);

# Create a user (creates a primary group for the user too)
subtest create_user => sub {
  my $user_form = {
      login_name     => 'шест',
      login_password => 'da',              #TODO: SHA1 login_name+login_password
      first_name     => 'Шести',
      last_name      => 'Шестак',
      email          => 'шести@хост.бг',
      disabled       => 0,
                  };
  $t->post_ok($users_url => form => $user_form)->status_is(201)
    ->header_is(Location => $user6_url, 'Location: /Ꙋправленѥ/users/6')
    ->content_is('', 'empty content');
  my $user_show = $t->get_ok($user6_url)->status_is(200);
  my $user      = $app->users->find_by_login_name('шест');
  for (values %$user_form) {
    $user_show->content_like(qr/$_/);
  }
  $t->get_ok($user6_url)->status_is(200);

  # Primary group for this user
  my $group = $app->groups->find($user->{id});    #now group has the same id
  is($group->{name} => $user->{login_name}, 'primary group name');
};

# Update a user
subtest update_user => sub {
  $t->put_ok($user6_url => form => {last_name => 'Седмак'})
    ->header_is(Location => $user6_url, 'Location: /Ꙋправленѥ/users/6')
    ->content_is('', 'empty content')->status_is(204);
};

# Remove a user
subtest remove_user => sub {
  $t->delete_ok($user6_url)
    ->header_is(Location => $users_url, 'Location: /Ꙋправленѥ/users')
    ->status_is(302);
  $t->get_ok($users_url)->status_is(200)
    ->content_like(qr|Ꙋправленѥ/Потребители|);
};

# Create stranici
my $stranici_url = $app->url_for('store_stranici')->to_string;
subtest create_stranici => sub {
  my $form = {
              alias       => 'относно',
              page_type   => 'заглавѥ',
              permissions => '-rwxr-xr-x',
              published   => 1,
              title       => 'Относно',
              body        => 'Някякъв по-дълъг теѯт, който е тяло на писанѥто.',
              language    => 'bg-bg'
             };
  $t->post_ok($stranici_url => form => $form)->status_is(201);
};

# Create celini
# subtest create_celini => sub {
# }
# Update celini
# Remove Celini
done_testing;
exit;


