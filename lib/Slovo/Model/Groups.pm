package Slovo::Model::Groups;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my $table = 'groups';

sub table { return $table }

my $loadable = sub {
  return (disabled => 0, id => {'>' => 0});
};

sub all ($self, $opts = {}) {
  $opts->{where} = {$loadable->(), %{$opts->{where} // {}}};
  $opts->{order_by} //= {-asc => ['id']};
  return $self->SUPER::all($opts);
}

# all groups with virtual column `is_member`.
# The 'admin' and 'guest' groups are not in the list.
# New admins are added only via the command line.
sub all_with_member ($m, $uid) {
  my $columns = <<"COLS";
    name, id, description AS title, disabled,
    coalesce((SELECT 1 from user_group
            WHERE user_id=$uid AND group_id=$table.id),0)
            AS is_member
COLS

  return $m->all({
    columns  => $columns,
    where    => {id => {-not_in => [1, 2]},},
    order_by => {-desc => ['is_member', 'id']}});
}

sub find ($self, $id) {
  return $self->dbx->db->select($table, undef, {$loadable->(), id => $id})->hash;
}


sub remove ($self, $id) {
  return $self->dbx->db->delete($table, {$loadable->(), id => $id});
}

sub save ($self, $id, $row) {
  return $self->dbx->db->update($table, $row, {$loadable->(), id => $id});
}

# Returns cached result of a check if the user is in the admin group.
sub is_admin ($m, $uid) {
  state $admins = {};
  state $Q      = <<"SQL";
    SELECT group_id FROM user_group
    WHERE user_id=? AND group_id=1
    LIMIT 1
SQL

  return $admins->{$uid} //= $m->dbx->db->query($Q, $uid)->hash;
}

1;
