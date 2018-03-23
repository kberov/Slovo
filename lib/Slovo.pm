package Slovo;
use Mojo::Base 'Mojolicious';

our $AUTHORITY = 'cpan:BEROV';
our $VERSION   = '2018.03.23';
our $CODENAME  = 'U+2C0A GLAGOLITIC CAPITAL LETTER INITIAL IZHE (Ⰺ)';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  return;
}

1;

=encoding utf8

=head1 NAME

Slovo - В началѣ бѣ Слово

=head1 SYNOPSIS

  use Slovo;
  blah blah blah


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.


=head1 USAGE


=head1 BUGS

Please open issues at L<https://github.com/kberov/Slovo>.

=head1 SUPPORT



=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    N/A
    berov@cpan.org
    http://i-can.eu

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.	

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<Mojolicious>

=cut


