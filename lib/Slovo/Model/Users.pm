package Slovo::Model::Users;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my $table    = 'users';
my $ug_table = 'user_group';
sub table { return $table }

sub groups_table { return Slovo::Model::Groups->table }

# Create a user and the primary group for the user.
# Add the primary group to $ug_table.
sub add ($self, $row) {
  my $db = $self->dbx->db;
  my $id;
  my $group_row = {
                   name        => $row->{login_name},
                   description => 'Главно множество за ' . $row->{login_name},
                   created_by  => $row->{created_by},
                   changed_by  => $row->{changed_by},
                   disabled    => $row->{disabled},
                  };
  eval {
    my $tx  = $db->begin;
    my $gid = $db->insert(groups_table, $group_row)->last_insert_id;
    $row->{group_id} = $gid;
    $id = $db->insert($table, $row)->last_insert_id;
    $db->insert($ug_table => {user_id => $id, group_id => $gid});
    $tx->commit;
  } || Carp::croak("Error creating user: $@");
  return $id;
}

my $loadable = sub {
  my $time = time;
  return (
          disabled   => 0,
          group_id   => {'>' => 0},
          start_date => {'<' => $time},
          stop_date  => [{'=' => 0}, {'>' => $time}],
         );
};

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  $opts->{columns} //= '*';
  my $where = {$loadable->(), %{$opts->{where} // {}}};
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind) = $abstr->select($table, $opts->{columns}, $where);
  $sql .= " LIMIT $opts->{limit}"
    . (defined $opts->{offset} ? " OFFSET $opts->{offset}" : '');
  return $self->dbx->db->query($sql, @bind)->hashes;
}


sub find ($self, $id) {
  return $self->dbx->db->select($table, undef, {id => $id, $loadable->()})
    ->hash;
}

sub find_by_login_name ($self, $login_name) {
  return
    $self->dbx->db->select($table, undef,
                           {login_name => $login_name, $loadable->()})->hash;
}

sub purge ($self, $id) {
  return $self->dbx->db->delete($table, {$loadable->(), id => $id});
}

sub remove ($self, $id) {
  return $self->dbx->db->update($table, {disabled => 1}, {id => $id});
}

#update a user
sub save ($m, $id, $row) {

  #never change the primary group
  delete $row->{group_id};
  my $groups;
  if ($row->{groups}) {
    $groups
      = ref $row->{groups} eq 'ARRAY'
      ? delete $row->{groups}
      : [delete $row->{groups}];
  }
  my $db = $m->dbx->db;

  state $gid_SQL= "(SELECT group_id FROM $table WHERE id=?)";
  eval {
    my $tx = $db->begin;
    $db->update($table, $row, {id => $id});

    # Remove all previous groups except primary and insert the selected groups.
    if ($groups) {
      $db->delete(
         $ug_table => {user_id => $id, group_id => {'!=' => \[$gid_SQL => $id]}}
      );
      for my $gid (@$groups) {
        $db->query("INSERT OR IGNORE INTO $ug_table VALUES (?,?)", $id, $gid);
      }
    }

    # disable/enable primary group if needed
    $db->update(groups_table,
                {disabled => $row->{disabled}},
                {id       => {'=' => \[$gid_SQL => $id]}})
      if defined $row->{disabled};
    $tx->commit;
  } || Carp::croak("Error updating $table: $@");
  return $id;
}

1;
