package Slovo::Model::Stranici;
use Mojo::Base -base, -signatures;

has 'dbx';

sub add ($self, $row) {
  return $self->dbx->db->insert('stranici', $row)->last_insert_id;
}

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind) = $abstr->select('stranici', '*', $opts->{where} // ());
  $sql .= " LIMIT $opts->{limit}"
    . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');
  return $self->dbx->db->query($sql, @bind)->hashes->to_array;
}

sub find ($self, $id) {
  return $self->dbx->db->select('stranici', undef, {id => $id})->hash;
}

sub remove ($self, $id) {
  return $self->dbx->db->delete('stranici', {id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update('stranici', $row, {id => $id});
}

1;
