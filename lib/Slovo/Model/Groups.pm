package Slovo::Model::Groups;
use Mojo::Base 'Slovo::Model', -signatures;

my $table = 'groups';

sub table { return $table }

sub add ($self, $row) {
  return $self->dbx->db->insert($table, $row)->last_insert_id;
}

my $loadable = sub {
  return (disabled => 0, id => {'>' => 0});
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
  return $self->dbx->db->select($table, undef, {$loadable->(), id => $id})
    ->hash;
}


sub remove ($self, $id) {
  return $self->dbx->db->delete($table, {$loadable->(), id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update($table, $row, {$loadable->(), id => $id});
}

1;
