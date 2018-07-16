package Slovo::Model::Celini;
use Mojo::Base 'Slovo::Model', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my $table = 'celini';

sub table { return $table }

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

sub all_for_display ($self, $page, $user, $language, $preview) {
  return
    $self->all(
              {
               where => {
                         page_id  => $page->{id},
                         language => $language,
                         %{$self->where_with_permissions($user, $preview)},
                        },
               order_by => [{-desc => 'featured'}, {-asc => [qw(id sorting)]},],
              }
    );
}
1;
