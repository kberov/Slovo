package Slovo::Controller::Upravlenie;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(unicode_strings);

# ANY /manage/
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index ($c) {
  state $menu = [qw(minion groups users domove stranici celini)];
  $c->stash->{menu} = [
    map {
      $_ =~ m'groups|minion|domove' && !$c->groups->is_admin($c->user->{id})
        ? ()
        : $_
    } @$menu
  ];
  return $c->render();
}

1;

=encoding utf8

=head1 NAME

Slovo::Controller::Upravlenie - the management dashboard

=head1 DESCRIPTION

Slovo::Controller::Upravlenie inherits all methods from L<Slovo::Controller> and implements the following.


=head1 ACTIONS

Slovo::Controller::Upravlenie implements the following actions C<under  => '/manage'>.

=head2 index

Route: C<{any  => '/', to => 'upravlenie#index', name => 'home_upravlenie'}>

Displays the main page C<under  => '/manage'>.


=head1 SEE ALSO

L<Slovo::Controller>

=cut
