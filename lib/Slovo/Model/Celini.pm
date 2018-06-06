package Slovo::Model::Celini;
use Mojo::Base 'Slovo::Model', -signatures;

my $table = 'celini';

sub table { return $table }

sub all_for_display ($self, $page, $user, $language, $прегледъ) {
  my $now = time;
  return $self->all(
    {
     where => {
       page_id  => $page->{id},
       language => $language,
       $прегледъ ? () : (deleted => 0),
       $прегледъ ? () : (start   => [{'=' => 0}, {'<' => $now}]),
       $прегледъ ? () : (stop    => [{'=' => 0}, {'>' => $now}]),
       -or => [

         # published and everybody can read and execute
         {published => 2, permissions => {-like => '%r_x'}},

         # preview of a page with elements, owned by this user
         {user_id => $user->{id}, permissions => {-like => '_r_x%'}},

         # preview of elements, which can be read and executed
         # by one of the groups to which this user belongs.
         {
          permissions => {-like => '____r_x%'},
          published => $прегледъ ? 1 : 2,

          # TODO: Implement adding users to multiple groups:
          group_id => \[
                       "IN (SELECT group_id from user_group WHERE user_id=?)" =>
                         $user->{id}
                       ],
         },

       ]
     },
     order_by => [{-desc => 'featured'}, {-asc => [qw(id sorting)]},],
    }
  );
}
1;
