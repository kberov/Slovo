package Slovo::Model::Domove;
use Mojo::Base 'Slovo::Model', -signatures;

use Mojo::Collection;

my $table = 'domove';
has table => $table;
has 'dbx';

sub find_by_host ($m, $h) {

  # Do not ask the database for the same thing on each request. Save some
  # method calls. We do not change domain names every day.
  state $cache = {};

  # If needed later, we may add more columns to this query.
  state $sql = <<"SQL";
    SELECT * FROM domove
    WHERE (? LIKE '%' || domain OR aliases LIKE ? OR ips LIKE ?)
    AND published = ? LIMIT 1
SQL
  return $cache->{$h} //= $m->dbx->db->query($sql, $h, "%$h%", "%$h%", 2)->hash;
}

# Returns all published domains and caches them. We expect not more than 100
# domains per Slovo instance to be served.
sub all ($d) {
  state $all = Mojo::Collection->new();
  return $all->size ? $all : $all
    = $d->SUPER::all({where => {published => {'>' => 1}}, order_by => {-asc => ['id']}});
}

1;
