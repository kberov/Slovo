package Slovo::Validator;
use Mojo::Base 'Mojolicious::Validator';


has filters => sub {
  +{
    %{$_[0]->SUPER::filters},
    xml_escape => sub { Mojo::Util::xml_escape($_[2]) },
   };
};

1;

=encoding utf8

=head1 NAME

Slovo::Validator - additional validator filters


=head1 FILTERS

Slovo::Validator inherits all filters from Mojo::Validator and implements the following new ones.

=head2 xml_escape

  $c->validation->optional(title => xml_escape => 'trim')->size(10, 255);

Uses L<Mojo::Util/xml_escape> to escape unsafe characters. Returns the escaped
string.

=head1 SEE ALSO

L<Mojolicious::Validator>, L<Mojolicious::Guides::Rendering/Form-validation>

=cut

