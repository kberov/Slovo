package Slovo::Controller::Upravlenie;
use Mojo::Base 'Slovo::Controller';

# This action will render a template
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index {
  my $self = shift;
  state $menu = [qw(groups users domove stranici celini)];
  return $self->render(menu => $menu);
}

1;
