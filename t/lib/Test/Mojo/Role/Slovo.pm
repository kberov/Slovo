package Test::Mojo::Role::Slovo;

BEGIN {
  binmode STDOUT => ':utf8';
  binmode STDERR => ':utf8';
}
use Mojo::Base -role, -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Test::More;
use Mojo::File qw(path tempdir);
use Mojo::ByteStream 'b';
use Mojo::Util qw(encode sha1_sum);
use Mojo::IOLoop::Server;

use FindBin;
my $default_from   = path($FindBin::Bin)->sibling('./');
my $random_tempdir = tempdir('slovoXXXX');

has authenticated  => 0;
has login_name     => 'краси';
has login_password => 'беров';
sub domain_aliases {'some.domain alias.domain alias2.domain'}

# Class method
# Install the app  from a path to a temporary path. Creates a log directory in
# installation directory to hide log output from screen and put it to slovo.log
# if $to_tempdir equals $random_tempdir.
# You can pass '/tmp/slovo' after $from. The tmp/slovo will not be
# automatically deleted and you can debug the installed application.
sub install ($class, $from = $default_from, $to_tempdir = $random_tempdir) {
  my $MOJO_HOME = path($to_tempdir);

  # idempotent
  $MOJO_HOME->remove_tree->make_path({mode => 0700});
  ok(-d $MOJO_HOME, "created $MOJO_HOME");
  $MOJO_HOME->child('log')->make_path({mode => 0700})
    if $to_tempdir eq $random_tempdir;
  path($from, 'lib')->list_tree({dir => 1})->each(
    sub ($f, $i) {
      $f =~ /\.sqlite$/ && return;    #do not copy existing database
      my $new = $MOJO_HOME->child($f->to_rel);
      (-d $f) && $new->make_path({mode => 0700});
      (-f $f) && $f->copy_to($new);
    }
  );
  unshift @INC, path($to_tempdir, 'lib')->to_string;
  return $class;
}

# use this method for the side effect of having a logged in user
sub login_ok ($t, $login_name = '', $login_password = '') {
  subtest login_ok => sub {
    my $login_url = $t->app->url_for('sign_in');

    $t->get_ok('/Ꙋправленѥ')->status_is(302)
      ->header_is(Location => $login_url, 'Location is /входъ');
    $t->get_ok('/входъ')->status_is(200)->text_is('head title' => 'Входъ');

    my $form = $t->fill_in_login_form($login_name, $login_password);
    my $body
      = $t->post_ok($login_url, {} => form => $form)->status_is(302)
      ->header_is(Location => '/', 'Location: /')
      ->content_is('', 'empty content')->tx->res->body;
    $t->authenticated($body eq '');
  };
  return $t;
}

sub fill_in_login_form ($t, $login_name = '', $login_password = '') {
  $login_name     ||= $t->login_name;
  $login_password ||= $t->login_password;
  my $csrf_token = $t->ua->get($t->app->url_for('sign_in'))
    ->res->dom->at('#sign_in [name="csrf_token"]')->{value};

  return {
          login_name => $login_name,
          csrf_token => $csrf_token,
          digest     => sha1_sum(
            $csrf_token . sha1_sum(encode('utf8', "$login_name$login_password"))
          ),
         };
}

sub login ($t, $login_name = '', $login_password = '') {
  my $form = $t->fill_in_login_form($login_name, $login_password);
  my $body = $t->ua->post($t->app->url_for('sign_in') => {} => form => $form)
    ->res->body;
  return $t->authenticated($body eq '')->authenticated;
}

# Tests creation of a domove record and returns the URL for GET, PUT, DELETE
sub create_edit_domain_ok ($t) {

  #authenticate user if not authenticated
  if (!$t->authenticated) {
    ok($t->login(), 'logged in');
  }
  $t->get_ok($t->app->url_for('create_domove'))->status_is(200);
  my $store_url   = $t->app->url_for('store_domove');
  my $TEST_DOMAIN = $ENV{TEST_DOMAIN} || $t->domain_aliases;
  my $domain      = [split /\s+/, $TEST_DOMAIN];
  my $form = {
              domain      => $domain->[0],
              aliases     => $TEST_DOMAIN,
              site_name   => 'У дома',
              description => 'Съвсем у дома',
              owner_id    => 5,
              group_id    => 5,
              published   => 2
             };
  my $edit_url = $t->post_ok($store_url => form => $form)->status_is(302)
    ->tx->res->headers->location;
  $t->get_ok($edit_url)->text_is('h2' => "1:$form->{domain}");

  $form->{aliases} .= ' alias2.domain';
  $t->put_ok($edit_url => form => $form)->status_is(302)
    ->header_is(Location => $edit_url);
  my $body = $t->get_ok($edit_url)->tx->res->body;
  like($body => qr/$form->{aliases}/, 'aliases changed');
  return $edit_url;
}

1;
