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
  ->text_is('#first_name' => 'first_name: Краси');

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
my $stranici_url  = $app->url_for('store_stranici')->to_string;
my $stranici_url4 = "$stranici_url/4";
my $sform = {
             alias       => 'събития',
             page_type   => 'обичайна',
             permissions => '-rwxr-xr-x',
             published   => 1,
             title       => 'Събития',
             body        => 'Някaкъв по-дълъг теѯт, който е тяло на писанѥто.',
             language    => 'bg-bg'
            };
subtest create_stranici => sub {
  $t->post_ok($stranici_url => form => $sform)->status_is(201)
    ->header_is(Location => $stranici_url4, 'Location: /Ꙋправленѥ/stranici/4')
    ->content_is('', 'empty content')->status_is(201);
  $t->get_ok($stranici_url4)->status_is(200)->content_like(qr/събития/);
  is(@{$app->celini->all({where => {alias => 'събития'}})}, 1,
     'only one title');
};

# Update stranici
subtest update_stranica => sub {
  $sform->{alias} = 'събитияsss';
  my $dom = $t->get_ok("$stranici_url4/edit?language=bg-bg")->tx->res->dom;
  $sform->{title_id} = $dom->at('input[name="title_id"]')->{value};
  $sform->{title}    = $dom->at('input[name="title"]')->{value};
  $sform->{body}     = $dom->at('textarea[name="body"]')->text;

  $t->put_ok($stranici_url4 => {Accept => '*/*'} => form => $sform)
    ->status_is(302);
  $t->get_ok($stranici_url4)->text_is('#alias' => 'alias: ' . $sform->{alias});
  is(@{$app->celini->all({where => {alias => 'събитияsss'}})},
     1, 'alias for title changed too');
};

# Create celini
my $cform = {
             page_id   => 4,
             title     => 'Целина',
             body      => 'Некаква целина',
             language  => 'bg-bg',
             data_type => 'целина'
            };

subtest create_celini => sub {
  $t->post_ok($app->url_for('store_celini') => form => $cform)
    ->header_is(Location => $app->url_for('show_celini', {id => 6}));
};

# Update celini
my $sh_up_url = $app->url_for('update_celini', {id => 6})->to_string;
subtest update_celini => sub {
  $cform->{title} = 'Заглавие на целината';
  $t->put_ok($sh_up_url => {} => form => $cform)->status_is(302)
    ->header_is(Location => $sh_up_url);

  $t->get_ok($sh_up_url)
    ->text_is('#alias' => 'alias: ' . Mojo::Util::slugify($cform->{title}, 1));
};

# Remove Celini
subtest remove_celini => sub {
  my $celini_url = $app->url_for('home_celini')->to_string;
  $t->delete_ok($sh_up_url)->header_is(Location => $celini_url)->status_is(302);
  $t->get_ok($celini_url)->status_is(200)
    ->element_exists_not('tr:nth-child(6)');
};

done_testing;
exit;


