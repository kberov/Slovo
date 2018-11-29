package Slovo::Controller::Upravlenie;
use Mojo::Base 'Slovo::Controller', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

# This action will render a template
## no critic qw(Subroutines::ProhibitBuiltinHomonyms)
sub index($c) {
  state $menu = [qw(minion groups users domove stranici celini)];
  return $c->render(
    menu => [
      map {
        $_ =~ m'groups|minion|domove' && !$c->groups->is_admin($c->user->{id})
          ? ()
          : $_
        } @$menu
    ]
  );
}

1;
