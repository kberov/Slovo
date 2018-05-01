package Slovo::Model::Celini;
use Mojo::Base 'Slovo::Model', -signatures;

my $table = 'celini';

sub table { return $table }

sub add ($self, $row) {
  return $self->dbx->db->insert('celini', $row)->last_insert_id;
}

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  $opts->{where} //= {};
  $opts->{order_by} //= {-asc => ['sorting', 'id']};
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind)
    = $abstr->select('celini', '*', $opts->{where}, $opts->{order_by});
  $sql .= " LIMIT $opts->{limit}"
    . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');
  return $self->dbx->db->query($sql, @bind)->hashes->to_array;
}

sub find ($self, $id) {
  return $self->dbx->db->select('celini', undef, {id => $id})->hash;
}

sub remove ($self, $id) {
  return $self->dbx->db->delete('celini', {id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update('celini', $row, {id => $id});
}

1;
