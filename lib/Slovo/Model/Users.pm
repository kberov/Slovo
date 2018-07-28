package Slovo::Model::Users;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my $table = 'users';

sub table { return $table }

# Create a primary group for the user and the user it self.
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
    my $tx = $db->begin;
    my $gid
      = $db->insert(Slovo::Model::Groups->table, $group_row)->last_insert_id;
    $row->{group_id} = $gid;
    $id = $db->insert($table, $row)->last_insert_id;
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
  my $where = {$loadable->(), %{$opts->{where} // {}}};
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind) = $abstr->select($table, '*', $where);
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

1;
