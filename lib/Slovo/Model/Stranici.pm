package Slovo::Model::Stranici;
use Mojo::Base 'Slovo::Model', -signatures;

use Slovo::Model::Celini;

my $table        = 'stranici';
my $celini_table = Slovo::Model::Celini->table;

has celini            => sub { $_[0]->c->celini };
has not_found_id      => 4;
has regular_page_type => sub { $_[0]->c->stash->{page_types}[1] };
has root_page_type    => sub { $_[0]->c->stash->{page_types}[0] };
has table             => $table;
has title_data_type   => sub { $_[0]->c->stash->{data_types}[0] };

# Returns a list of page aliases and titles in the current language for
# displaying as breadcrumb. No permission filters are applied because if the
# user gets to this page, he should have passed through all filters from the
# parent page to this page. This SQL is supported now even in MySQL 8.
# https://stackoverflow.com/questions/324935/mysql-with-clause#325243
# https://sqlite.org/lang_with.html
sub breadcrumb ($m, $pid, $l) {
  state $sqla = $m->dbx->abstract;
  $pid //= 0;
  my $lang_like = {'c.language' => $m->celini->language_like($l)};
  state $LSQL = ($sqla->where($lang_like) =~ s/WHERE//r);
  my @lang_like = map { $_->{'-like'} } $sqla->values($lang_like);
  state $SQL = <<"SQL";
WITH RECURSIVE pids(p)
  AS(VALUES(?) UNION SELECT pid FROM $table s, pids WHERE s.id = p)
  SELECT s.alias, c.title, c.language, s.id, s.pid, c.id as title_id FROM $table s, $celini_table c
  WHERE s.id IN pids
    AND c.page_id = s.id
    AND $LSQL
    -- title
    AND c.data_type = '${\ $m->title_data_type }'
    -- root
    AND s.page_type !='${\ $m->root_page_type }';
SQL
  my $rows = $m->dbx->db->query($SQL, $pid, @lang_like)->hashes;

  return $rows;
}

# Returns a structure for a 'where' clause to be shared among select methods
# for pages to be displayed in the site.
sub _where_with_permissions ($m, $user, $domain_name, $preview) {

  my $now = time;

  # Match by domain or one of the domain aliases or IPs - in that order. This
  # is to give chance to all domains and their aliases to match in case the
  # request URL does not start with an IP. In case the request URL starts with
  # an IP (e.g. http://127.0.0.1/some/route) the first domain record with that
  # IP will take the request.
  state $domain_name_sql = <<"SQL";
= (SELECT id FROM domove
    WHERE (? LIKE '%' || domain OR aliases LIKE ? OR ips LIKE ?) AND published = ? LIMIT 1)
SQL

  return {
    # must not be deleted
    $preview ? () : ("$table.deleted" => 0),

    # must be available within a given range of time values
    $preview ? () : ("$table.start" => [{'=' => 0}, {'<' => $now}]),
    $preview ? () : ("$table.stop"  => [{'=' => 0}, {'>' => $now}]),

    # the page must be published and belong to the current domain
    $m->where_domain_is($domain_name),

    # TODO: May be drop this column as 'hidden' can be
    # implemented by putting '.' as first character for the alias.
    $preview ? () : ("$table.hidden" => 0),

    -or => [

      # published and everybody can read and execute
      # This page can be stored on disk and served as static page
      # after displayed for the first time
      {"$table.published" => 2, "$table.permissions" => {-like => '%r_x'}},

      # preview of a page, owned by this user
      {"$table.user_id" => $user->{id}, "$table.permissions" => {-like => '_r_x%'}},

      # preview of a page, which can be read and executed
      # by one of the groups to which this user belongs.
      {
        "$table.permissions" => {-like => '____r_x%'},
        "$table.published"   => $preview ? 1 : 2,
        "$table.group_id"    =>
          \["IN (SELECT group_id from user_group WHERE user_id=?)" => $user->{id}],
      },
    ]};
}

# Returns part of the where clause for $domain_name($c->host_only) as a HASH pair.
sub where_domain_is ($m, $domain_name) {

  # Match by domain or one of the domain aliases or IPs - in that order. This
  # is to give chance to all domains and their aliases to match in case the
  # request URL does not start with an IP. In case the request URL starts with
  # an IP (e.g. http://127.0.0.1/some/route) the first domain record with that
  # IP will take the request.
  state $domain_name_sql = <<"SQL";
= (SELECT id FROM domove
    WHERE (? LIKE '%' || domain OR aliases LIKE ? OR ips LIKE ?) AND published=2 LIMIT 1)
SQL

  # the page must belong to the current domain
  return ("$table.dom_id" =>
      \[$domain_name_sql, => ($domain_name, "%$domain_name%", "%$domain_name%")]);
}

# Find a page by $alias which can be seen by the current user
sub find_for_display ($m, $alias, $user, $domain_name, $preview) {

  # 0. WHERE alias = $alias failed to match
  # 1. Suppose the user stumbled on a link with the old most recent alias.
  # 2. Look for the most recent id which had such $alias in the given table.
  state $old_alias_SQL = <<"SQL";
 = (SELECT new_alias FROM aliases
    WHERE alias_table='$table'
    AND (old_alias=?)
    ORDER BY ID DESC LIMIT 1)
 OR $table.id=(SELECT alias_id FROM aliases
    WHERE alias_table='$table'
    AND (old_alias=? OR new_alias=?)
    ORDER BY ID DESC LIMIT 1)
SQL

  #local $m->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $m->dbx->db->select(
    $table, undef,
    {
      alias => [$alias, \[$old_alias_SQL => $alias, $alias, $alias]],
      %{$m->_where_with_permissions($user, $domain_name, $preview)}})->hash;
}

# Inserts a new row in table stranici and title row in table celini for this
# page. Most columns in the title row are set to the values of the page row.
# The title always serves as default container for other celini in the page -
# in other words, its permissions start with 'd'.
# Returns the id of the new page record or croaks with the eventual database
# error.
sub add ($m, $row) {
  $row->{dom_id}    //= 0;
  $row->{page_type} //= $m->regular_page_type;
  $row->{tstamp}    //= time - 1;
  $row->{start}     //= $row->{tstamp};
  my $title            = {};
  my $mandatory_fields = [qw(title language body data_format tstamp user_id
    group_id changed_by alias permissions published)];

  for (@$mandatory_fields) {
    Carp::croak "The following field is mandatory to create a page: $_"
      unless defined $row->{$_};
  }

  for (qw(title language body data_format keywords description)) {
    $title->{$_} = delete $row->{$_} if exists $row->{$_};
  }

  @$title{qw(sorting data_type created_at user_id
    group_id changed_by alias permissions published)} = (
    0,
    $m->title_data_type,
    @$row{qw(tstamp user_id
      group_id changed_by alias permissions published)});

  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $title->{page_id} = $db->insert($table, $row)->last_insert_id;
    $db->insert($celini_table, $title);
    $tx->commit;
  } || Carp::croak("Error creating stranici record: $@");
  return $title->{page_id};
}


sub find_for_edit ($m, $id, $l) {
  my $db    = $m->dbx->db;
  my $p     = $db->select($table, undef, {id => $id})->hash;
  my $title = $db->select(
    $celini_table,
    'title,body,language,id as title_id',
    {
      page_id   => $id,
      language  => $m->celini->language_like($l),
      data_type => $m->title_data_type,
      sorting   => 0,
      box       => $m->celini->main_boxes,
    },
    {-asc => ['sorting', 'id']})->hash // {};
  return {%$p, %$title};
}

sub save ($m, $id, $row) {
  my $title = {};
  $row->{tstamp} = time - 1;

  # Delete undefined fields. We do not want anything to be set to NULL.
  # TODO: Set the fields to NOT NULL in the database table - not here.
  for (keys %$row) {
    delete $row->{$_} unless defined $row->{$_};
  }

  # The title serves as default container for other celini in the page and it
  # has the same permissions like the page as well as other properties.
  my $title_related_fields = [qw(
    title body language data_format alias
    changed_by permissions published
    user_id group_id start stop deleted)];

  for (@$title_related_fields) {
    Carp::croak("Error updating $table: The field 'title_id' is required "
        . " in case '$_' is updated!")
      if (!defined $row->{title_id} && defined $row->{$_});
  }

  # Get the values for the title record for this page in celini
  if (defined $row->{title_id}) {
    $title->{page_id} = $id;
    for (qw(title body language id data_format)) {
      if (defined $row->{$_}) { $title->{$_} = delete $row->{$_}; }
    }
    for (qw(alias changed_by permissions published
      tstamp user_id group_id start stop deleted))
    {
      if (defined $row->{$_}) { $title->{$_} = $row->{$_}; }
    }
    $title->{id} = delete $row->{title_id};
  }

  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $m->upsert_aliases($db, $id, $row->{alias}) if $row->{alias};
    $db->update($table, $row, {id => $id});
    if (defined $title->{id}) {

      $title->{permissions} =~ s/^[\-l]/d/ if $title->{permissions};
      $db->update($celini_table, $title, {id => $title->{id}});
    }
    $tx->commit;
  } || Carp::croak("Error updating $table and $celini_table: $@");

  return $id;
}

sub remove ($m, $id) {
  my $db = $m->dbx->db;
  return eval {
    my $tx = $db->begin;
    $m->remove_aliases($db, $id, $table);
    $db->update($table, {deleted => 1}, {id => $id});
    $tx->commit;
  } || Carp::croak("Error updating $table: $@");
}

# Transforms a column accordingly as passed from $opts->{columns} and returns
# the transformed column.
my sub _transform_columns ($col) {
  if ($col eq 'title' or $col eq 'language') {
    return "$/$celini_table.$col AS $col";
  }
  elsif ($col eq 'is_dir') {
    return "$/coalesce((SELECT 1 WHERE $table.permissions LIKE 'd%'),0) AS is_dir";
  }

  # do not touch any other made up custom columns
  elsif ($col =~ /\s+AS\s+/msx) {
    return $col;
  }

  # local $db->dbh->{TraceLevel} = "3|SQL";
  return "$/$table.$col AS $col";
}

# Returns all pages for listing in a sidebar or via Swagger API. Beware not to
# mention one column twice as a key in the WHERE clause, because only the
# second mention will remain for generating the SQL.
sub all_for_list ($self, $user, $domain_name, $preview, $l, $opts = {}) {
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
    "$celini_table.language"  => $self->celini->language_like($l),
    "$celini_table.box"       => [$self->celini->main_boxes, {'=' => undef}],
    %{$self->_where_with_permissions($user, $domain_name, $preview)},
    %{$self->celini->where_with_permissions($user, $preview)}, %{$opts->{where} // {}}};

  # local $db->dbh->{TraceLevel} = "3|SQL";
  return $self->all($opts);
}

# Returns all pages for editing under 'home_stranici' or via Swagger API for
# which the user has write permissions.  Beware not to mention one column twice
# as a key in the WHERE clause, because only the second mention will remain for
# generating the SQL.
sub all_for_edit ($self, $user, $domain_name, $l, $opts = {}) {
  $opts->{table} = [$table, $celini_table];
  my @columns = map { _transform_columns($_) } @{$opts->{columns}};
  $opts->{columns} = join ",", @columns;
  $opts->{order_by} //= {-asc => [$table . '.sorting']};
  my $pid = delete $opts->{pid};
  $opts->{where} = {
    defined $pid
    ? ("$table.pid" => $pid, "$table.id" => {'!=' => $pid})
    : ("$table.page_type" => $self->root_page_type),

    "$celini_table.page_id"   => {-ident => "$table.id"},
    "$celini_table.data_type" => $self->title_data_type,
    "$celini_table.language"  => $self->celini->language_like($l),
    "$celini_table.box"       => [{-in => $self->celini->main_boxes}, {'=' => undef}],
    $self->where_domain_is($domain_name), %{$self->readable_by($user)},
    %{$opts->{where} // {}}};

  # local $self->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $self->all($opts);
}


# Get all pages under current (home) page which have title which is directory
# (i.e. contains articles) and get $opts->{celini_opts}{limit} articles for
# each. $opts contains only two keys (stranici_opts, and celini_opts). They
# will be passed respectively to all_for_list() and
# all_for_display_in_stranica().
sub all_for_home ($m, $user, $domain_name, $preview, $l, $opts = {}) {
  my $stranici_opts = {
    where => {"$celini_table.permissions" => {-like => 'd%'}},
    %{delete $opts->{stranici_opts}}};
  my $celini_opts = {
    columns => 'title, id, alias, substr(body,1,555) as teaser, language',
    limit   => 6,
    where   => {"$celini_table.data_type" => {'!=' => 'title'}},
    %{delete $opts->{celini_opts}}};

  return $m->all_for_list($user, $domain_name, $preview, $l, $stranici_opts)->each(
    sub ($p, $i) {
      state $SQL = <<"SQL";
=(SELECT id FROM $celini_table
  WHERE pid=? AND page_id=? AND data_type=? limit 1)
SQL
      my $opts = {%$celini_opts};    #copy
      $opts->{where}{"$celini_table.pid"} = \[$SQL, 0, $p->{id}, 'title'];
      $p->{articles}
        = $m->celini->all_for_display_in_stranica($p, $user, $l, $preview, $opts);
    });
}

# Returns list of languages for this page in which we have readable by the
# current user content.
# Arguments: Current page, user, preview mode or not.
sub languages ($m, $p, $u, $prv) {
  my $db    = $m->dbx->db;
  my $where = {
    page_id =>
      \["=(SELECT id FROM $table WHERE alias=? AND dom_id=?)", $p->{alias}, $p->{dom_id}],
    data_type => $m->title_data_type,
    box       => $m->celini->main_boxes,

    # and those titles are readable by the current user
    %{$m->celini->where_with_permissions($u, $prv)},
  };

  #local $db->dbh->{TraceLevel} = "3|SQL";
  return $db->select($celini_table, 'DISTINCT title,language',
    $where, {-asc => [qw(sorting id)]})->hashes;
}

1;

