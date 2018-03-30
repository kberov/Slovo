package Slovo::Model::Users;
use Mojo::Base -base, -signatures;

has 'dbx';

sub add ($self, $row) {
  return $self->dbx->db->insert('users', $row)->last_insert_id;
}

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  my $sql = $self->dbx->abstract->select('users', '*');
  $sql .= " LIMIT $opts->{limit}"
    . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');
  return $self->dbx->db->query($sql)->hashes->to_array;
}

sub find ($self, $id) {
  return $self->dbx->db->select('users', undef, {id => $id})->hash;
}

sub remove ($self, $id) {
  return $self->dbx->db->delete('users', {id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update('users', $row, {id => $id});
}

1;
