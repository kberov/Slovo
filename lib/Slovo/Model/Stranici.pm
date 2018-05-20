package Slovo::Model::Stranici;
use Mojo::Base 'Slovo::Model', -signatures;
use Slovo::Model::Celini;
my $table        = 'stranici';
my $celini_table = Slovo::Model::Celini->table;

sub table { return $table }

sub find_for_display ($self, $alias, $user) {
  my $db = $self->dbx->db;
  my $now = time;

  # Get the page
  return $db->select(
    $table, undef,
    {
     alias   => $alias,
     deleted => 0,
          start   => [{'=' => 0}, {'<' => $now}],
     stop    => [{'=' => 0}, {'>' => $now}],

     # TODO: implement multidomain support
     # domain_id => $domain_id
     # TODO: May be drop this column as 'hidden' can be
     # implemented by putting '.' as first cahracter for the alias.
     hidden => 0,
     -or    => [
       {published => 2, permissions => {-like => '%r_x'}},
       {
        published   => {'<'   => 2},
        permissions => {-like => '_r_x%'},
        user_id     => $user->{id}
       },
       {
        published   => {'<'   => 2},
        permissions => {-like => '____r_x%'},
        group_id    => $user->{group_id}
       },

# TODO: Implement multiple groups for users and then:
# group_id => {-in => \'SELECT group_id from user_group WHERE user_id='.$user->{id} }
     ]
    }
  )->hash;

}


sub add ($m, $row) {
  $row->{start} //= $row->{tstamp} = time - 1;
  my $title = {};
  @$title{qw(title language body)} = delete @$row{qw(title language body)};
  @$title{qw(sorting data_type created_at user_id group_id changed_by alias)}
    = (0, 'заглавѥ', @$row{qw(tstamp user_id group_id changed_by alias)});
  my $id;
  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $id = $db->insert($table, $row)->last_insert_id;
    $title->{page_id} = $id;
    $db->insert($celini_table, $title);
    $tx->commit;
  } || Carp::croak("Error creating stranici record: $@");
  return $id;
}


sub find_for_edit ($self, $id, $language) {
  my $db = $self->dbx->db;
  my $p = $db->select($table, undef, {id => $id})->hash;
  my $title = $db->select(
                          $celini_table,
                          'title,body,language,id as title_id',
                          {
                           page_id   => $id,
                           language  => $language,
                           data_type => 'заглавѥ',
                           sorting   => 0,
                           box       => 'main'
                          },
                          {-asc => ['sorting', 'id']}
                         )->hash // {};
  return {%$p, %$title};
}

sub save ($m, $id, $row) {
  my $title = {};
  @$title{qw(page_id title body language id alias changed_by)} = (
                                 $id,
                                 delete @$row{qw(title body language title_id)},
                                 @$row{qw(alias changed_by)}
  );
  my $db = $m->dbx->db;
  eval {
    my $tx = $db->begin;
    $db->update($table,        $row,   {id => $id});
    $db->update($celini_table, $title, {id => $title->{id}});
    $tx->commit;
  } || Carp::croak("Error updating stranici record: $@");

  return $id;
}

sub remove ($self, $id) {
  return $self->dbx->db->update($table, {deleted => 1}, {id => $id});
}

1;
