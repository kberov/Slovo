package Slovo::Model::Celini;
use Mojo::Base 'Slovo::Model', -signatures;

my $table = 'celini';

sub table { return $table }

sub all_for_display ($self, $page, $user, $language) {
  my $now = time;
  return $self->all(
    {
     where => {
       page_id  => $page->{id},
       language => $language,
       deleted  => 0,
#     start   => [{'=' => 0}, {'<' => $now}],
#     stop    => [{'=' => 0}, {'>' => $now}],
#       -or      => [
#         {published => 2, permissions => {-like => '%r_x'}},
#         {
#          published   => {'<'   => 2},
#          permissions => {-like => '_r_x%'},
#          user_id     => $user->{id}
#         },
#         {
#          published   => {'<'   => 2},
#          permissions => {-like => '____r_x%'},
#          group_id    => $user->{group_id}
#         },

# TODO: Implement multiple groups for users and then:
# group_id => {-in => \'SELECT group_id from user_group WHERE user_id='.$user->{id} }
#       ]
     },
     order_by => [{-desc => 'featured'}, {-asc => [qw(id sorting)]},],
    }
  );
}
1;
