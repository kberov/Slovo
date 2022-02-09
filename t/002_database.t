use Mojo::Base -strict;
use FindBin qw($Bin);
use Test::More;
use Test::Mojo;
use Mojo::File qw(path);

# $ENV{MOJO_MIGRATIONS_DEBUG} = 1;
my $t = Test::Mojo->with_roles('+Slovo')->install(

# from      => to
# "$Bin/.." => '/home/berov/opt/t.com/slovo',
# 0777
)->new('Slovo');
my $app     = $t->app;
my $moniker = $app->moniker;
my $mode    = $app->mode;
my $home    = $app->home;
my $dbx     = $app->dbx;
my $db      = $dbx->db;


my $triggers = sub {

  # Try to move a page under itself (ѿносно)
  my $table = $app->stranici->table;
  my $str   = $db->select($table => '*' => {dom_id => 0, alias => 'ѿносно'})->hash;
  eval { $db->update($table, {pid => $str->{id}}, {id => $str->{id}}); };

  # note $@;
  like $@ => qr/execute failed: s.pid cannot be equal to s.id/,
    'pid cannot be equal to id';

  # Create a regular page which is not a directory and move 'ѿносно' under it
  my $new_page_id = $app->stranici->add({
    alias       => 'нова',
    body        => 'някакъв текст',
    changed_by  => 5,
    data_format => 'text',
    group_id    => 5,
    language    => 'bg',
    page_type   => 'regular',
    permissions => '-rwxrwxr-x',
    published   => 0,
    title       => 'нова',
    tstamp      => time,
    user_id     => 5,
  });

  eval { $db->update($table, {pid => $str->{id}}, {id => $new_page_id}); };

  # note $@;
  like $@ => qr/failed: The parent page must be a directory/,
    'the parent page must be a directory';

  # Celini писания
  # Try to move a celina under itself (ѿносно)
  my $ctable = $app->celini->table;
  my $cel    = $db->select($ctable => '*' => {id => 1, alias => 'писания'})->hash;
  eval { $db->update($ctable, {pid => $cel->{id}}, {id => $cel->{id}}); };

  # note $@;
  like $@ => qr/execute failed: c.pid cannot be equal to c.id/,
    'pid cannot be equal to id';

  # целина Ѿносно в целина Писания
  # 1|0|писания|-rwxr-xr-x|Писания
  # 4|0|ѿносно|-rwxr-xr-x|Ѿносно
  $app->celini->save(1, {permissions => '-rwxr-xr-x'});
  eval { $db->update($ctable, {pid => 1}, {id => 4}); };

  note $@;
  like $@ => qr/failed: The parent celina must be a directory/,
    'the parent celina must be a directory';
};

subtest Triggers => $triggers;

done_testing;
