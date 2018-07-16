package Slovo::Model::Stranici;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Slovo::Model::Celini;

my $table        = 'stranici';
my $celini_table = Slovo::Model::Celini->table;

has not_found_id    => 4;
has table           => $table;
has title_data_type => 'заглавѥ';

# Returns a structure for a 'where' clause to be shared among select methods
# for pages to be displayed in the site.
sub _where_with_permissions ($m, $user, $domain, $preview) {

  my $now = time;
  state $domain_sql = <<"SQL";
= (SELECT id FROM domove
    WHERE (? LIKE '%' || domain OR ips like ?) AND published = ? LIMIT 1)
SQL

  return {
    # must not be deleted
    $preview ? () : ("$table.deleted" => 0),

    # must be available within a given range of time values
    $preview ? () : ("$table.start" => [{'=' => 0}, {'<' => $now}]),
    $preview ? () : ("$table.stop"  => [{'=' => 0}, {'>' => $now}]),

    # the page must belong to the current domain
    "$table.dom_id" => \[$domain_sql, => ($domain, "%$domain%", 2)],

    # TODO: May be drop this column as 'hidden' can be
    # implemented by putting '.' as first character for the alias.
    $preview ? () : ("$table.hidden" => 0),

    -or => [

      # published and everybody can read and execute
      # This page can be stored on disk and served as static page
      # after displayed for the first time
      {"$table.published" => 2, "$table.permissions" => {-like => '%r_x'}},

      # preview of a page, owned by this user
      {
       "$table.user_id"     => $user->{id},
       "$table.permissions" => {-like => '_r_x%'}
      },

      # preview of a page, which can be read and executed
      # by one of the groups to which this user belongs.
      {
       "$table.permissions" => {-like => '____r_x%'},
       "$table.published"   => $preview ? 1 : 2,

    # TODO: Implement 'adding users to multiple groups in /Ꙋправленѥ/users/:id':
       "$table.group_id" => \[
           "IN (SELECT group_id from user_group WHERE user_id=?)" => $user->{id}
       ],
      },
    ]
  };
}

# Find a page by $alias which can be seen by the current user
sub find_for_display ($m, $alias, $user, $domain, $preview) {

  return
    $m->dbx->db->select(
                        $table, undef,
                        {
                         alias => $alias,
                         %{
                           $m->_where_with_permissions(
                                                       $user, $domain, $preview
                                                      )
                          }
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
    }
    = (
    0,
    $m->title_data_type,
    @$row{
      qw(tstamp user_id
        group_id changed_by alias permissions published)
    }
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
                           data_type => $self->title_data_type,
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

  # local $db->dbh->{TraceLevel} = "3|SQL";
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

# Transforms a column accordingly as passed from $opts->{columns} and returns
# the transfromed column.
## no critic (Modules::RequireEndWithOne)
my sub _transform_columns($col) {
  if ($col eq 'title') {
    return "$/$celini_table.title AS $col";
  }
  elsif ($col eq 'is_dir') {
    return "$/EXISTS (SELECT 1 WHERE $table.permissions LIKE 'd%') AS is_dir";
  }
  return "$/$table.$col AS $col";
}

# Returns all pages for listing in a sidebar or via Swagger API. Beware not to
# mention one column twice as a key in the WHERE clause, because only the
# second mention will remain for generating the SQL.
sub all_for_list ($self, $user, $domain, $preview, $language, $opts = {}) {
  $opts->{table} = [$table, $celini_table];
  my @columns = map { _transform_columns($_) } @{$opts->{columns}};
  $opts->{columns} = join ",", @columns;
  my $pid = delete $opts->{pid} // 0;
  $opts->{where} = {
    "$table.pid" => $pid,

    # avoid any potential recursion
    # must not be the not_found_id
    "$table.id" =>
      {-not_in => [$self->not_found_id, $pid ? () : {-ident => "$table.pid"}]},
    "$celini_table.page_id"   => {-ident => "$table.id"},
    "$celini_table.data_type" => $self->title_data_type,
    "$celini_table.language"  => $language,
    "$celini_table.box" => [{-in => ['main', 'главна', '']}, {'=' => undef}],
    %{$self->_where_with_permissions($user, $domain, $preview)},
    %{$self->c->celini->where_with_permissions($user, $preview)},
    %{$opts->{where} // {}}
                   };
  return $self->all($opts);
}

1;
