package Slovo::Model;
use Mojo::Base -base, -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";


has 'dbx';
has c => sub { Slovo::Controller->new() };
sub table { Carp::croak 'Method not implemented' }

sub all ($self, $opts = {}) {
  $opts->{limit} //= 100;
  $opts->{limit} = 100 unless $opts->{limit} =~ /^\d+$/;
  $opts->{offset} //= 0;
  $opts->{offset} = 0 unless $opts->{offset} =~ /^\d+$/;
  $opts->{where} //= {};
  $opts->{order_by} //= {-asc => ['id', 'pid', 'sorting']};

  # $self->c->debug('opts:', $opts);
  state $abstr = $self->dbx->abstract;
  my ($sql, @bind)
    = $abstr->select($opts->{table} // $self->table,
                     $opts->{columns}, $opts->{where}, $opts->{order_by});
  $sql .= " LIMIT $opts->{limit}"
    . ($opts->{offset} ? " OFFSET $opts->{offset}" : '');

  # local $self->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $self->dbx->db->query($sql, @bind)->hashes;
}

sub save ($self, $id, $row) {

  # local $self->dbx->db->dbh->{TraceLevel} = "3|SQL";
  return $self->dbx->db->update($self->table, $row, {id => $id});
}

sub find {
  return $_[0]->dbx->db->select($_[0]->table, undef, {id => $_[1]})->hash;
}

sub remove {
  return $_[0]->dbx->db->delete($_[0]->table, {id => $_[1]});
}

sub add {
  return $_[0]->dbx->db->insert($_[0]->table, $_[1])->last_insert_id;
}

1;
