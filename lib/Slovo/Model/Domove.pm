package Slovo::Model::Domove;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
my $table = 'domove';
has table => $table;
has 'dbx';

sub find_by_host ($m, $h) {

  # Do not ask the database for the same thing on each request. Save some
  # method calls. We do not change domain names every day.
  state $cache = {};

  # If needed later, we may add more columns to this query.
  state $sql = <<"SQL";
    SELECT id,domain FROM domove
    WHERE (? LIKE '%' || domain OR aliases LIKE ? OR ips LIKE ?)
    AND published = ? LIMIT 1
SQL
  return $cache->{$h} //= $m->dbx->db->query($sql, $h, "%$h%", "%$h%", 2)->hash;
}

1;
