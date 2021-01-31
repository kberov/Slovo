package Slovo::Model;
use Mojo::Base -base, -signatures;

has 'dbx';
has c => sub { Slovo::Controller->new() };

sub table {
  Carp::croak "Method not implemented. Please implement it in ${\ ref($_[0])}.";
}

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  $opts->{where} //= {};
  my $table = $opts->{table} || $self->table;
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind)
    = $abstr->select($table, $opts->{columns}, $opts->{where}, $opts->{order_by});
  $sql .= " LIMIT $opts->{limit}" . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');

  #local $self->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return
    eval { $self->dbx->db->query($sql, @bind)->hashes }
    || Carp::croak("Wrong SQL:$sql\n or bind values: @bind\n$@");
}

# similar to all but retuns only one row
sub one ($m, $o) {
  return $m->dbx->db->select($m->table, $o->{columns}, $o->{where})->hash;
}

#update a record
sub save ($self, $id, $row) {

  # local $self->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $self->dbx->db->update($self->table, $row, {id => $id});
}

sub find_where ($m, $where = {}) {

  # local $m->dbx->db->dbh->{TraceLevel} = "3|SQL";
  state $abstr = $m->dbx->abstract;
  if (ref $where eq 'HASH' ? keys %$where : @$where) {
    my ($sql, @bind) = $abstr->where($where);
    return $m->dbx->db->query("SELECT * FROM ${\ $m->table } $sql LIMIT 1", @bind)->hash;
  }
  return;
}

# Find by ID.
sub find {
  return $_[0]->dbx->db->select($_[0]->table, undef, {id => $_[1]})->hash;
}


sub remove ($m, $id) {
  my $db    = $m->dbx->db;
  my $table = $m->table;
  return eval {
    my $tx = $db->begin;
    $m->remove_aliases($db, $id, $table);
    $db->delete($table, {id => $id});
    $tx->commit;
  } || Carp::croak("Error deleting record from $table: $@");
}

sub add {

  # local $_[0]->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $_[0]->dbx->db->insert($_[0]->table, $_[1])->last_insert_id;
}

# Returns hashref for where clause where permissions allow the user to read
# records.
sub readable_by ($self, $user) {
  my $t = $self->table;
  return {
    -or => [

      # everybody can read
      {"$t.permissions" => {-like => '%r__'}},

      # user is owner
      {
        "$t.user_id" => $user->{id},

        # "$table.permissions" => {-like => '_r__%'}
      },

      # a page or content, which can be read
      # by one of the groups to which this user belongs.
      {
        "$t.permissions" => {-like => '____r__%'},
        "$t.group_id"    => \[
          "IN (?,(SELECT group_id from user_group WHERE user_id=?))" =>
            ($user->{group_id}, $user->{id})
        ],
      },
    ],
  };
}

# Returns hashref for where clause where permissions allow the user to write
# records.
sub writable_by ($self, $user) {
  my $t = $self->table;
  return {
    -or => [

      # everybody can write
      {"$t.permissions" => {-like => '%_w_'}},

      # user is owner
      {"$t.user_id" => $user->{id}, "$t.permissions" => {-like => '__w_%'}},

      # a page, which can be written
      # by one of the groups to which this user belongs.
      {
        "$t.permissions" => {-like => '_____w_%'},
        "$t.group_id"    => \[
          "IN (?,(SELECT group_id from user_group WHERE user_id=?))" =>
            ($user->{group_id}, $user->{id})
        ],
      },
    ],
  };
}

# Inserts relations for redirects from old to new alias. Must be
# called only from save() and before $db->update($table,..)
sub upsert_aliases ($m, $db, $alias_id, $new_alias) {
  my $alias_table = $m->table;
  my $SQL         = <<"SQL";
    INSERT OR IGNORE INTO aliases
    (old_alias,new_alias,alias_id,alias_table)
    VALUES (
      (SELECT alias FROM $alias_table WHERE id=? AND alias != ?),
      ?,?,?)
SQL
  return $db->query($SQL, $alias_id, $new_alias, $new_alias, $alias_id, $alias_table);
}

# Remove aliases history for a record from a given table.
sub remove_aliases ($m, $db, $id, $table) {
  return $db->delete('aliases', {alias_table => $table, alias_id => $id});
}

1;


