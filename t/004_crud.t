use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
my $t = Test::Mojo->with_roles('+Slovo')->install()->new('Slovo');
isa_ok($t->app, 'Slovo');
$t->login_ok('краси', 'беров');

my $users_url = '/Ꙋправленѥ/users';
$t->get_ok("$users_url/5")->status_is(200)
  ->text_is('body > p:nth-child(6)' => 'Краси');

# Disabled User
$t->get_ok("$users_url/0")->status_is(404);

# Disabled group
$t->get_ok('/Ꙋправленѥ/groups/0')->status_is(404);

# Create a user
subtest create_user => sub {
  $t->post_ok(
              $users_url => form => {
                                     login_name     => 'шеsт',
                                     login_password => 'da',
                                     first_name     => 'Шести',
                                     last_name      => 'Шестак',
                                     email          => 'шести@хост.бг',
                                    }
    )->status_is(201)
    ->header_is(
              Location => '/' . b("Ꙋправленѥ")->encode->url_escape . '/users/6')
    ->content_is('');
};

# Update a user
# Remove a user


done_testing;

