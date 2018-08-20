package Slovo::Validator;
use Mojo::Base 'Mojolicious::Validator', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::ByteStream 'b';
use Mojo::File 'path';
has filters => sub {
  +{
    %{$_[0]->SUPER::filters},
    xml_escape => sub { Mojo::Util::xml_escape($_[2]) },
    slugify    => sub { Mojo::Util::slugify($_[2], 1) },
   };
};


1;

=encoding utf8

=head1 NAME

Slovo::Validator - additional validator filters


=head1 FILTERS

Slovo::Validator inherits all filters from Mojo::Validator and implements the following new ones.

=head2 slugify

  $v->required('alias', 'slugify')->size(0, 255);

Generate URL slug for bytestream with L<Mojo::Util/"slugify">.

=head2 xml_escape

  $c->validation->optional(title => xml_escape => 'trim')->size(10, 255);

Uses L<Mojo::Util/xml_escape> to escape unsafe characters. Returns the escaped
string.

=head1 SEE ALSO

L<Mojolicious::Validator>, L<Mojolicious::Guides::Rendering/Form-validation>

=cut

