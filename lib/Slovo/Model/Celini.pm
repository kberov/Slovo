package Slovo::Model::Celini;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my $table = 'celini';

# Structure for matching a language parameter.
sub language_like ($m, $l) {
  my ($l1, $l2) = $l =~ /^([A-z]{2})\-?([A-z]{2})?/;
  $l2 ||= $l1;
  return [{'=' => $l}, {-like => "$l1%"}, {-like => "%$l2"}];
}
sub table { return $table }

sub breadcrumb ($m, $p_alias, $path, $l, $user, $preview) {
  state $abstr       = $m->dbx->abstract;
  state $s_table     = $m->c->stranici->table;
  state $page_id_SQL = "= (SELECT id FROM $s_table WHERE alias=?)";
  my (@SQL, @BINDS);
  for my $cel (@$path) {
    my ($u_SQL, @bind) = $abstr->select(
      $table, undef,
      {
       "page_id"  => \[$page_id_SQL, $p_alias],
       "alias"    => $cel,
       "language" => $m->celini->language_like($l),
       %{$m->where_with_permissions($user, $preview)},

      }
    );
    push @SQL,   $u_SQL;
    push @BINDS, @bind;
  }
  my $sql = join("\nUNION\n", @SQL);
  return $m->dbx->db->query($sql, @BINDS)->hashes;

}

sub where_with_permissions ($self, $user, $preview) {
  my $now = time;

  return {
    $preview ? () : ("$table.deleted" => 0),
    $preview ? () : ("$table.start"   => [{'=' => 0}, {'<' => $now}]),
    $preview ? () : ("$table.stop"    => [{'=' => 0}, {'>' => $now}]),
    -or => [

      # published and everybody can read and execute
      {"$table.published" => 2, "$table.permissions" => {-like => '%r_x'}},

      # preview of a page with elements, owned by this user
      {
       "$table.user_id"     => $user->{id},
       "$table.permissions" => {-like => '_r_x%'}
      },

      # preview of elements, which can be read and executed
      # by one of the groups to which this user belongs.
      {
       "$table.permissions" => {-like => '____r_x%'},
       "$table.published"   => $preview ? 1 : 2,

       # TODO: Implement adding users to multiple groups:
       "$table.group_id" => \[
           "IN (SELECT group_id from user_group WHERE user_id=?)" => $user->{id}
       ],
      },
    ]
  };
}

sub all_for_display_in_stranica ($self, $page, $user, $l, $preview, $opts = {})
{
  return $self->all(
    {
     where => {
       page_id      => $page->{id},
       "$table.pid" => 0,             #only content belonging directly to a page
       language => $self->language_like($l),
       %{$self->where_with_permissions($user, $preview)},
       %{delete $opts->{where} // {}}
              },
     order_by => [{-desc => 'featured'}, {-asc => [qw(id sorting)]},],
     %$opts,
    }
  );
}

sub find_for_display ($m, $alias, $user, $l, $preview, $where = {}) {

  #local $m->dbx->db->dbh->{TraceLevel} = "3|SQL";
  my $_where = {
                alias    => $alias,
                language => $m->language_like($l),
                box      => {-in => [qw(главна main)]},
                %{$m->where_with_permissions($user, $preview)}, %$where
               };
  return $m->dbx->db->select($table, undef, $_where)->hash;
}
1;
