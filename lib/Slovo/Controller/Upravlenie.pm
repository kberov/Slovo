package Slovo::Controller::Upravlenie;
use Mojo::Base 'Slovo::Controller';

# This action will render a template
sub index {
  my $self = shift;
  state $menu = [qw(groups users)];
  return $self->render(menu => $menu);
}

1;
