package Slovo::Model::Stranici;
use Mojo::Base 'Slovo::Model', -signatures;

my $table = 'stranici';

sub table { return $table }

sub add ($m, $row) {
  my $title = {};
  @$title{qw(title language body)} = delete @$row{qw(title language body)};
  $m->c->debug($title);
  my $id;
  $row->{start} //= $row->{tstamp} = time - 1;
  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $id = $db->insert($table, $row)->last_insert_id;
    @$title{qw(page_id sorting data_type created_at user_id group_id )}
      = ($id, 0, 'заглавѥ', @$row{qw(tstamp user_id group_id)});
    $db->insert(Slovo::Model::Celini->table, $title);
    $m->c->debug($title);
    $tx->commit;
  } || Carp::croak("Error creating stranici record: $@");
  return $id;
}

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind) = $abstr->select($table, '*', $opts->{where} // ());
  $sql .= " LIMIT $opts->{limit}"
    . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');
  return $self->dbx->db->query($sql, @bind)->hashes->to_array;
}

sub find ($self, $id) {
  return $self->dbx->db->select($table, undef, {id => $id})->hash;
}

sub remove ($self, $id) {
  return $self->dbx->db->delete($table, {id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update($table, $row, {id => $id});
}

1;
