package Test::Mojo::Role::Slovo;

BEGIN {
  binmode STDOUT => ':utf8';
  binmode STDERR => ':utf8';
}
use Mojo::Base -role, -signatures;
use Test::More;
use Mojo::File qw(path tempdir);
use Mojo::ByteStream 'b';
use Mojo::Util qw(encode sha1_sum);
use FindBin;
my $default_from   = path($FindBin::Bin)->sibling('./');
my $random_tempdir = tempdir('slovoXXXX');

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
sub login_ok ($t, $login_name, $login_password) {
  subtest login_ok => sub {
    $t->get_ok('/Ꙋправленѥ')->status_is(302)->header_is(
                               Location => '/' . b('входъ')->encode->url_escape,
                               'Location is /входъ');
    $t->get_ok('/входъ')->status_is(200)->text_is('head title' => 'Входъ');

#get the csrf field
    my $csrf_token
      = $t->tx->res->dom->at('#sign_in [name="csrf_token"]')->{value};
    my $form = {
       login_name     => 'краси',
       login_password => '',
       csrf_token     => $csrf_token,
       digest         => sha1_sum(
         encode(
           'utf8',
           $csrf_token . sha1_sum(encode('utf8', "$login_name,$login_password"))
         )
       ),
    };

    $t->post_ok('/входъ', {} => form => $form)->status_is(200)
      ->content_is('ok');
  };
  return $t;
}
1;
