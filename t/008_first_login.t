use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
use Mojo::File qw(path);
use Mojo::Util qw(encode sha1_sum url_escape);
my $t = Test::Mojo->with_roles('+Slovo')->install(

# '.' => '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;
$t->login_ok();

#create anew user and simulate addition of token for first login
my $users_url = $app->url_for('home_users')->to_string;
my ($token_row, $user);
my $create_user = sub {
  my $user_form = {
                   login_name     => 'шестi',
                   login_password => sha1_sum(encode('utf8', "шестilabala")),
                   first_name     => 'Шести',
                   last_name      => 'Шестак',
                   email          => 'шести@хост.бг',
                   disabled       => 1,
                  };
  $t->post_ok($users_url => form => $user_form)->status_is(302);
  $user = $app->users->find_by_login_name('шестi');
  ok(!defined $user, 'disabled user is not findable');
  $user = $app->users->find_where({login_name => 'шестi'});
  is($user->{disabled} => 1, 'new disabled user created');
  $app->minion->perform_jobs;
  $token_row = $app->dbx->db->select(
                                     'first_login',
                                     '*',
                                     {
                                      from_uid => $user->{created_by},
                                      to_uid   => $user->{id}
                                     }
                                    )->hash;
  ok($token_row => 'token for first login creataed by job');
  my $jobs = $app->dbx->db->select('minion_jobs', '*')->hashes;
  ok($jobs->[0]->{finished} => 'first job is finished');
  ok(!$jobs->[1]->{finished}, 'second job is not finished');
};

my $first_login = sub {
  $t->get_ok('/първи-входъ/' . $token_row->{token})->status_is(200)
    ->element_exists('[name="first_name"]')
    ->element_exists('[name="last_name"]');
  my $from_u = $app->users->find($user->{created_by});
  $t->post_ok(
              '/първи-входъ/',
              form => {
                       first_name => $from_u->{first_name},
                       last_name  => $from_u->{last_name},
                       token      => $token_row->{token}
                      }
             );
  $t->status_is(302)
    ->header_is(Location => $app->url_for('edit_users' => {id => $user->{id}}));
  $app->minion->perform_jobs;
  my $jobs = $app->dbx->db->select('minion_jobs', '*')->hashes;
  ok($jobs->[2]->{finished} => 'third job is finished');
  ok(!$jobs->[1]->{finished}, 'second job is not finished');
  ok(
     !defined $app->dbx->db->select(
                                    'first_login', '*',
                                    {token => $token_row->{token}}
       )->hash,
     'delete_first_login successful'
    );
};
subtest create_user => $create_user;
subtest first_login => $first_login;
done_testing;

