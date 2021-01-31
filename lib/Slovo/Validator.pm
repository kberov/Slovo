package Slovo::Validator;
use Mojo::Base 'Mojolicious::Validator', -signatures;

# can this $name with $value do $sub with @args?
my sub _can ($v, $name, $value, $sub, @args) {
  return !$sub->($v, $name, $value, @args);
}

sub new {
  my $self = shift->SUPER::new(@_);

  # new filters
  $self->add_filter(xml_escape => sub { Mojo::Util::xml_escape($_[2]) });
  $self->add_filter(slugify    => sub { Mojo::Util::slugify($_[2], 1) });

  # new checks
  $self->add_check(is => \&_can);
  $self->add_check(
    equals => sub ($v, $name, $value, $eq) {
      unless ($value eq $eq) {
        return 1;
      }
      return;
    });
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Validator - additional validator filters and checks

=head1 CHECKS

Slovo::Validator inherits all checks from Mojolicious::Validator and implements
the following new ones.

=head2 is

A custom check -- some code reference which returns true on success, false
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

