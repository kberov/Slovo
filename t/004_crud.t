use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::ByteStream 'b';
use Mojo::File qw(path);
use Mojo::Util qw(decode encode sha1_sum);
my $t = Test::Mojo->with_roles('+Slovo')->install(

# '.' => '/tmp/slovo'
)->new('Slovo');
my $app = $t->app;
isa_ok($app, 'Slovo');
$t->login_ok();

my $users_url      = $app->url_for('home_users')->to_string;
my $groups_url     = $app->url_for('home_groups')->to_string;
my $user6_url      = $app->url_for('show_users', id => 6)->to_string;
my $edit_user6_url = $app->url_for('edit_users', id => 6);
$t->get_ok("$users_url/5")->status_is(200)->text_is('#first_name' => 'first_name: Краси');

# no privileges to edit other users
$t->get_ok("$users_url/2")->status_is(302)
  ->header_is(Location => $app->url_for('home_upravlenie'), 'Location: /manage');

# no privileges to edit groups
$t->get_ok("$groups_url/2")->status_is(302)
  ->header_is(Location => $app->url_for('home_upravlenie'), 'Location: /manage');

# Add the logged in user краси to 'admin' group.
$app->dbx->db->insert('user_group', {user_id => 5, group_id => 1});

# Disabled group
$t->get_ok("$groups_url/0")->status_is(404);

# Create a user (creates a primary group for the user too)
my $create_user = sub {
  my $user_form = {
    login_name     => 'шестi',
    login_password => sha1_sum(encode('utf8', "шестilabala")),
    first_name     => 'Шести',
    last_name      => 'Шестак',
    email          => 'шести@хост.бг',
    disabled       => 0,
  };
  $t->post_ok($users_url => form => $user_form)->status_is(302)->header_is(
    Location => $users_url . '/store_result/1',
    'Location: /manage/users/store_result/1'
  )->content_is('', 'empty content');
  my $user_show = $t->get_ok($user6_url)->status_is(200);
  my $user      = $app->users->find(6);
  for (values %$user_form) {
    $user_show->content_like(qr/$_/);
  }
  $t->get_ok($user6_url)->status_is(200);

  # the primary group is checked
  $t->get_ok($edit_user6_url)->status_is(200)
    ->element_exists('input[name="groups"][checked][value="6"]');

  # Primary group for this user
  my $group = $app->groups->find($user->{group_id});
  is($group->{name} => $user->{login_name}, 'primary group name');
};

# Update a user
my $update_user = sub {
  my $groups = [4, 5];
  $t->put_ok($user6_url => form => {last_name => 'Седмак', groups => $groups})
    ->header_is(Location => $user6_url, 'Location: /manage/users/6')
    ->content_is('', 'empty content')->status_is(302);
  $t->get_ok($edit_user6_url)->status_is(200);
  for (@$groups, 6) {
    $t->element_exists(qq|input[name="groups"][checked,value="$_"]|);
  }
};

# Remove a user
my $remove_user = sub {
  $t->delete_ok($user6_url)->header_is(Location => $users_url, 'Location: /manage/users')
    ->status_is(302);
  $t->get_ok($users_url)->status_is(200)->content_like(qr|manage/Потребители|);
};

# Create stranici
my $stranici_url = $app->url_for('store_stranici')->to_string;
my $sform        = {
  alias       => 'събития',
  page_type   => 'обичайна',
  permissions => '-rwxr-xr-x',
  published   => 1,
  title       => 'Събития',
  body        => 'Нѣкaкъв по-дълъг теѯт, който е тѣло на писанѥто.',
  language    => 'bg-bg',
  data_format => 'text'
};
my $new_page_id      = 0;
my $stranici_url_new = "$stranici_url/";
my $create_stranici  = sub {
  $t->post_ok($stranici_url => form => $sform)->status_is(302);
  $new_page_id = $app->dbx->db->select('stranici', 'max(id) as id')->hash->{id};
  $stranici_url_new .= $new_page_id;
  $t->header_is(
    Location => "$stranici_url_new/edit",
    "Location: /manage/stranici/$new_page_id/edit"
  )->content_is('', 'empty content');
  $t->get_ok($stranici_url_new)->status_is(200)->content_like(qr/събития/);
  my $title
    = $app->celini->all({where => {page_id => $new_page_id, data_type => 'title'}});
  is(@$title, 1, 'only one title');

  # get some title properties to check in the next subtest
  $sform->{title_id} = $title->[0]{id};
  $sform->{title}    = $title->[0]{title};
};

# List all stranici as an expandable tree
my $read_stranici = sub {
  my $url = $app->url_with('home_stranici');

  $t->get_ok($url)->text_is('div.mui-panel.breadcrumb > a:nth-child(2)' => '⸙');
  $t->text_is('div.mui-panel.pages > ul.fa-ul > '
      . 'li.fa-li > ul.fa-ul > li.fa-li > a:nth-child(2)' => 'писания');
  $t->get_ok($url->query([pid => 1]))
    ->text_is('div.mui-panel.breadcrumb > a:nth-child(3)' => 'писания');
  $t->element_exists('div.mui-panel.pages > ul.fa-ul > '
      . 'li.fa-li > ul.fa-ul > li.fa-li > i.fa-folder-open');
  $t->text_is('div.mui-panel.pages > ul.fa-ul > '
      . 'li.fa-li > ul.fa-ul > li.fa-li > a.mui--color-deep-orange' => 'писания');
};

# Update stranici
my $update_stranica = sub {
  $sform->{alias} = 'събитияsss';
  my $dom = $t->get_ok("$stranici_url_new/edit?language=bg-bg")->tx->res->dom;
  is(
    $dom->at('input[name="title_id"]')->{value} => $sform->{title_id},
    'proper hidden title_id'
  );

  is($dom->at('input[name="title"]')->{value} => $sform->{title}, 'proper title');
  $sform->{body} = $dom->at('textarea[name="body"]')->text;

  $t->put_ok($stranici_url_new => {Accept => '*/*'} => form => $sform)->status_is(204)
    ->content_is('');
  $sform->{redirect} = 'show_stranici';
  $t->put_ok($stranici_url_new => {Accept => '*/*'} => form => $sform)->status_is(302)
    ->header_is(Location => $app->url_for('show_stranici' => {id => $new_page_id}));
  my $aliases
    = $app->dbx->db->select('aliases', '*', {new_alias => $sform->{alias}})->hash;
  is_deeply(
    $aliases => {
      id          => 1,
      new_alias   => $sform->{alias},
      old_alias   => 'събития',
      alias_table => 'stranici',
      alias_id    => $new_page_id
    },
    'created proper new/old alias relation for stranici'
  );
  $t->get_ok($stranici_url_new)->text_is('#alias' => 'alias: ' . $sform->{alias});
  is(@{$app->celini->all({where => {alias => 'събитияsss'}})},
    1, 'alias for title changed too');
};

# Create celini
my $cform = {
  page_id     => 4,
  title       => 'Цѣлина',
  body        => 'Нѣкаква цѣлина',
  language    => 'bg-bg',
  data_type   => 'paragraph',
  data_format => 'html'
};
my $max_id = $app->dbx->db->query("SELECT max(id) as id FROM celini")->hash->{id} + 2;

my $create_celini = sub {

  # add a new image as base64 data.
  my $images = path('t/data/images')->list_tree()->map(sub {
    my $img = shift;
    my ($ext) = $img =~ /\.(\w+)$/;
    return
        '<img src="data:image/'
      . $ext
      . ';base64,'
      . b($img->slurp)->b64_encode('') . '" />';
  });
  $cform->{body} .= $images->join($/);
  $t->post_ok($app->url_for('store_celini') => form => $cform)
    ->header_is(Location => $app->url_for('show_celini', {id => $max_id}));
  $cform = $app->celini->find($max_id);
  unlike(
    $cform->{body} => qr/<img.+?src=['"]data\:.+?base64/mso,
    'No base64 src in body.'
  );
  for ('01.png', '02.gif', '03.jpeg') {
    my $img = $app->home->child('domove/localhost/public/img',
      sha1_sum(encode('UTF-8' => 'цѣлина')) . '-' . $_);
    ok(-s $img, "Image *-$_ is created on disk.");
    my ($img_path) = $img =~ m|public(/.+)$|;
    like(
      $cform->{body} => qr/src="$img_path"/,
      'Base64 src is replaced with path to image.'
    );
  }

# In the next subtest we change the title and the alias will be created from it.
  delete $cform->{alias};
};

# Update celini
my $sh_up_url     = $app->url_for('update_celini', {id => $max_id})->to_string;
my $update_celini = sub {
  my $old_title = $cform->{title};
  $cform->{title} = 'Заглавие на цѣлината';
  $t->put_ok($sh_up_url => {} => form => $cform)->status_is(204);
  my $new_alias = Mojo::Util::slugify($cform->{title}, 1);
  $t->get_ok($sh_up_url)->text_is('#alias' => 'alias: ' . $new_alias);
  my $aliases = $app->dbx->db->select('aliases', '*', {new_alias => $new_alias})->hash;
  is_deeply(
    $aliases => {
      id          => 3,
      new_alias   => $new_alias,
      old_alias   => Mojo::Util::slugify($old_title, 1),
      alias_table => 'celini',
      alias_id    => $max_id
    },
    'created proper new/old alias relation for celini'
  );

# change permisssions so on the next update user has enough permissions to write.
  $cform->{permissions} = '-rwxrwxr-x';
  $t->put_ok($sh_up_url => {} => form => $cform)->status_is(204);

  # change ownership.
  $cform->{user_id} = 4;
  $t->put_ok($sh_up_url => {} => form => $cform)->status_is(204);
  $cform->{redirect} = 'show_celini';
  $t->put_ok($sh_up_url => {Accept => '*/*'} => form => $cform)->status_is(302)
    ->header_is(Location => $app->url_for('show_celini' => {id => $max_id}));
  my $e_celini_url = $app->url_for('edit_celini', {id => $max_id})->to_string;
  $t->get_ok($e_celini_url)->status_is(200)
    ->text_like('#permissions > .mui-row > .mui-col-md-3 > span' => qr'Test 2')
    ->text_is('select[name="group_id"]>option[selected]'    => 'краси')
    ->text_is('select[name="permissions"]>option[selected]' => $cform->{permissions});

};

# Remove Celini
my $remove_celini = sub {
  my $celini_url = $app->url_for('home_celini')->to_string;
  $t->delete_ok($sh_up_url)->header_is(Location => $celini_url)->status_is(302);

  $t->get_ok($celini_url)->status_is(200)
    ->element_exists_not("table tbody tr:nth-child($max_id)");

  # TODO: In the far future think about creating cleanup job using Minion
  # that scans celini for unused images and deletes those images.
};

my $crud_domain = sub {
  my $delete_url = $t->create_edit_domain_ok();
  my $list_url   = $t->delete_ok($delete_url)->status_is(302)->tx->res->headers->location;

  # no link for editing the deleted record
  $t->get_ok($list_url)->status_is(200)->element_exists_not(qq|a [href="$delete_url"]|);

};
my $user_permissions = sub {
  $t->get_ok($app->url_for('sign_out'))->status_is(302);

  # Use another user
  $t->login('test2', 'test2');

  # user is not able to change a page with r-x for others
  # permissions: drwxr-xr-x
  my $sform = {%$sform};    #copy
  $sform->{alias} = $sform->{title} = 'blabla1';
  my $id        = 6;
  my $e_str_url = $app->url_for('edit_stranici'   => {id => $id});
  my $u_str_url = $app->url_for('update_stranici' => {id => $id});

# page redirects back to edit_stranici with flash message "Failed validation for: permissions,writable"
  $t->put_ok($u_str_url => {Accept => '*/*'} => form => $sform)->status_is(302)
    ->header_is(Location => $e_str_url);
  $t->get_ok($e_str_url)
    ->text_is('.field-with-error' => 'Failed validation for: permissions, writable');

  # make the page writable to others
  my $permissions = 'drwxr-xrwx';
  $app->dbx->db->update('stranici', {permissions => $permissions}, {id => $id});

  # Now user is able to udate the page
  $sform->{permissions} = $permissions;

  $t->put_ok('/manage/stranici/' . $id => {Accept => '*/*'} => form => $sform)
    ->status_is(302);

  $t->get_ok('/manage/stranici/' . $id)->text_like(
    '#permissions' => qr/\s$permissions$/,
    "writable permissions for others:'$permissions'"
  );
  $t->get_ok('/manage/celini/19')
    ->text_like('#title' => qr/\s$sform->{title}$/, "title changed to '$sform->{title}'");

  #user is not able to change another's user permissions
  $sform->{permissions} = 'drwxrwxrwx';
  $t->put_ok($u_str_url => {Accept => '*/*'} => form => $sform)->status_is(302);

  #change page ownership and change permissions
  $permissions = 'dr-xr-xr-x';
  $app->dbx->db->update(
    'stranici',
    {user_id => 4, group_id => 4, permissions => $permissions},
    {id      => $id});

  #invalid permissions notation!
  $sform->{permissions} = 'drwxrRxrwx';
  $t->put_ok($u_str_url => {Accept => '*/*'} => form => $sform)->status_is(302);

  $sform->{permissions} = 'drwxr-xr-x';
  $t->put_ok('/manage/stranici/' . $id => {Accept => '*/*'} => form => $sform)
    ->status_is(302);
  $sform->{permissions} = 'dr-xrwxr-x';
  $t->put_ok('/manage/stranici/' . $id => {Accept => '*/*'} => form => $sform)
    ->status_is(302);
  $sform->{permissions} = 'dr-xr-xrwx';
  $t->put_ok('/manage/stranici/' . $id => {Accept => '*/*'} => form => $sform)
    ->status_is(302);
  $sform->{permissions} = 'd---------';
  $t->put_ok('/manage/stranici/' . $id => {Accept => '*/*'} => form => $sform)
    ->status_is(302);

  #now page should not be listed in /manage/stranici for other users
  $t->get_ok($app->url_for('sign_out'))->status_is(302);

  # Use another user
  $t->login('краси', 'беров');
  $t->get_ok('/manage/stranici')->status_is(200)
    ->element_exists_not('html body table tbody tr.deleted', "page $id not listed");
  delete $sform->{title_id};

# change permisssions so on the next update user has enough permissions to write.
  $sform->{alias}       = 'alabalanicaaaa';
  $sform->{permissions} = '-rwxrwxr-x';

  $t->post_ok($stranici_url => {} => form => $sform)->status_is(302);
  $new_page_id = $app->dbx->db->select('stranici', 'max(id) as id')->hash->{id};
  my $stranica_url = $app->url_for('update_stranici', id => $new_page_id);
  $t->put_ok($stranica_url => {Accept => '*/*'} => form => $sform)->status_is(302);

  # change ownership.
  $sform->{user_id} = 4;
  $t->put_ok($stranica_url => {} => form => $sform)->status_is(302);
  $t->get_ok($app->url_for('edit_stranici', id => $new_page_id))->status_is(200)
    ->text_like('#permissions > .mui-row > .mui-col-md-3 > span' => qr'Test 2')
    ->text_is('select[name="group_id"]>option[selected]'    => 'краси')
    ->text_is('select[name="permissions"]>option[selected]' => $cform->{permissions});
};

subtest create_user => $create_user;
subtest update_user => $update_user;
subtest remove_user => $remove_user;

subtest create_stranici => $create_stranici;
subtest read_stranici   => $read_stranici;
subtest update_stranica => $update_stranica;

subtest create_celini => $create_celini;
subtest update_celini => $update_celini;
subtest remove_celini => $remove_celini;

subtest crud_domain      => $crud_domain;
subtest user_permissions => $user_permissions;

done_testing;
