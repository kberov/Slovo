package Slovo::Controller::Example;
use Mojo::Base 'Slovo::Controller';
use feature qw(lexical_subs unicode_strings);

# This action will render a template
sub welcome {
  my $self = shift;
  my $msg  = 'Добре дошли в приложението „Слово“!';

  # Render template "example/welcome.html.ep" with message
  return $self->render(msg => $msg);
}

1;
