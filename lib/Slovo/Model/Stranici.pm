package Slovo::Model::Stranici;
use Mojo::Base 'Slovo::Model', -signatures;
use Slovo::Model::Celini;
my $table        = 'stranici';
my $celini_table = Slovo::Model::Celini->table;

sub table { return $table }

# Find a page by $alias which can be seen by the current user
sub find_for_display ($m, $alias, $user, $дом, $прегледъ) {
  my $now = time;
  state $domain_sql = <<"SQL";
= (SELECT id FROM domove
    WHERE (? LIKE '%' || domain OR ips like ?) AND published = ? LIMIT 1)
SQL

  return $m->dbx->db->select(
    $table, undef,
    {
     alias => $alias,
     $прегледъ ? () : (deleted => 0),
     $прегледъ ? () : (start   => [{'=' => 0}, {'<' => $now}]),
     $прегледъ ? () : (stop    => [{'=' => 0}, {'>' => $now}]),

     # the page must belong to the current domain
     dom_id => \[$domain_sql, => ($дом, "%$дом%", 2)],

     # TODO: May be drop this column as 'hidden' can be
     # implemented by putting '.' as first character for the alias.
     $прегледъ ? () : (hidden => 0),

     -or => [

       # published and everybody can read and execute
       # This page can be stored on disk and served as static page
       # after displayed for the first time
       {published => 2, permissions => {-like => '%r_x'}},

       # preview of a page, owned by this user
       {user_id => $user->{id}, permissions => {-like => '_r_x%'}},

       # preview of a page, which can be read and executed
       # by one of the groups to which this user belongs.
       {
        permissions => {-like => '____r_x%'},
        published => $прегледъ ? 1 : 2,

        # TODO: Implement 'adding users to multiple groups':
        group_id => \[
           "IN (SELECT group_id from user_group WHERE user_id=?)" => $user->{id}
        ],
       },
     ]
    }
  )->hash;
}


sub add ($m, $row) {
  $row->{tstamp} = time - 1;
  $row->{start} //= $row->{tstamp};
  my $title = {};
  @$title{qw(title language body)} = delete @$row{qw(title language body)};
  @$title{
    qw(sorting data_type created_at user_id
    group_id changed_by alias permissions published)
    } = (
       0, 'заглавѥ',
       @$row{qw(tstamp user_id 
       group_id changed_by alias permissions published)}
        );
  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $title->{page_id} = $db->insert($table, $row)->last_insert_id;
    $db->insert($celini_table, $title);
    $tx->commit;
  } || Carp::croak("Error creating stranici record: $@");
  return $title->{page_id};
}


sub find_for_edit ($self, $id, $language) {
  my $db = $self->dbx->db;
  my $p = $db->select($table, undef, {id => $id})->hash;
  my $title = $db->select(
                          $celini_table,
                          'title,body,language,id as title_id',
                          {
                           page_id   => $id,
                           language  => $language,
                           data_type => 'заглавѥ',
                           sorting   => 0,
                           box       => 'main'
                          },
                          {-asc => ['sorting', 'id']}
                         )->hash // {};
  return {%$p, %$title};
}

sub save ($m, $id, $row) {
  my $title = {};

  # Get the values for celini
  @$title{
    qw(page_id title body language id alias changed_by permissions published)}
    = (
       $id,
       delete @$row{qw(title body language title_id)},
       @$row{qw(alias changed_by permissions published)}
      );
  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $db->update($table,        $row,   {id => $id});
    $db->update($celini_table, $title, {id => $title->{id}});
    $tx->commit;
  } || Carp::croak("Error updating stranici record: $@");

  return $id;
}

sub remove ($self, $id) {
  return $self->dbx->db->update($table, {deleted => 1}, {id => $id});
}

1;
