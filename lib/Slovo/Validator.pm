package Slovo::Validator;
use Mojo::Base 'Mojolicious::Validator', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::ByteStream 'b';
use Mojo::File 'path';
has filters => sub {
  return {
          %{$_[0]->SUPER::filters},
          xml_escape => sub { Mojo::Util::xml_escape($_[2]) },
          slugify    => sub { Mojo::Util::slugify($_[2], 1) },
         };
};

has checks => sub {
  return {
    %{$_[0]->SUPER::checks},

    # some generic custom checks
    can => \&_can,
    is  => \&_can,
         };
};

sub _can ($v, $name, $value, $sub, @args) {
  return !$sub->($v, $name, $value, @args);
}

1;

=encoding utf8

=head1 NAME

Slovo::Validator - additional validator filters and checks

=head1 CHECKS

Slovo::Validator inherits all checks from Mojolicious::Validator and implements
the following new ones.

=head2 is

A custom check -- some code reference which returns true on succes, false
otherwise.

  # in the action
  $v->required('id')->is(\&_writable_by, $c->stranici, $c->user);

  # in the same or parent controller
  sub _writable_by ($v, $id_name, $id_value, $m, $user) {
    return !!$m->find_where({$id_name => $id_value, %{$m->writable_by($user)}});
  }

  # or simply
  $v->required('sum')->is(sub($v, $name, $value) {
    $v->param('one') + $v->param('two') == $value
  });

=head2 can

An alias for L</is>.

=head1 FILTERS

Slovo::Validator inherits all filters from Mojolicious::Validator and
implements the following new ones.

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

