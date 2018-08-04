package Slovo::Plugin::TagHelpers;
use Mojo::Base 'Mojolicious::Plugin::TagHelpers', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Scalar::Util 'blessed';

my $_select_box = sub ($c, $name, $options, %attrs) {
  return $c->tag(
    span => class => 'field ' . $name => sub {
      my $label = $c->label_for($name => delete $attrs{label} // ucfirst $name);
      $c->param($name => delete $attrs{value}) if exists $attrs{value};
      return $label . ' ' . $c->select_field($name, $options, %attrs);
    }
  );
};

sub register ($self, $app, $config) {
  $self->SUPER::register($app) unless exists $app->renderer->helpers->{t};

  # Override select_field. Allow a value to be passed.
  $app->helper(select_box => $_select_box);
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::TagHelpers - additional and advanced tag helpers

=head1 SYNOPSIS

  <%=
  select_box
    page_type => [['Regular' => 'обичайна'], ['Root page' => 'коренъ',]],
    required => 1, label => 'Page type'
  %>


=head1 DESCRIPTION

Slovo::Plugin::TagHelpers extends L<Mojolicious::Plugin::TagHelpers> and
implements some additional helpers for form fields. DefaultHelpers and
TagHelpers are loaded unconditionally after all other mandatory for Slovo
plugins.


=head1 HELPERS

The following helpers are currently implemented.

=head2 select_box

    <%=
    select_box
      published => [['for (p)review' => 1], ['no' => 0], ['Yes' => 2]],
      value     => 2,
      label     => 'Published';
    %>

    <%=
    select_box
      colors => [(white green red blue yellow)],
      value     => [qw(white green)],
      label     => 'Favorite colors'
      multiple => undef
    %>

This is a wrapper for L<Mojolicious::Plugin::TagHelpers/select_field> with
additional optional attributes C<label> and C<value>. If label is not provided,
the name of the field is used as label. If value is not provided, it is
retreived from input C<$c-E<gt>every_param($name)> by the wrapped
C<select_field>. If value is provided it does C<$c-E<gt>param($name =E<gt>
$attrs{value})>. The generated tags are wrapped in a common C<span> tag with
C<class="field $name">.

=head1 METHODS

The usual method is implemented.

=head2 register

Calls the parent's register if needed and registers additional helpers in Slovo application.


=head1 SEE ALSO

L<Mojolicious::Plugin::TagHelpers>, L<Slovo::Plugin::DefaultHelpers>

=cut

