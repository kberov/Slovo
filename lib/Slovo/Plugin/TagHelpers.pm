package Slovo::Plugin::TagHelpers;
use Mojo::Base 'Mojolicious::Plugin::TagHelpers', -signatures;
use feature qw(unicode_strings);
use Scalar::Util 'blessed';
use Mojo::DOM::HTML 'tag_to_html';
use Mojo::Collection 'c';

sub register ($self, $app, $config) {
  $self->SUPER::register($app) unless exists $app->renderer->helpers->{t};

  $app->helper(select_box  => \&_select_box);
  $app->helper(html_substr => \&_html_substr);
  return $self;
}

sub _select_box ($c, $name, $options, %attrs) {
  return $c->tag(
    span => class => 'field ' . $name => sub {
      my $label = $c->label_for($name => delete $attrs{label} // ucfirst $name);
      $c->param($name => delete $attrs{value}) if exists $attrs{value};
      return $label . ' ' . $c->select_field($name, $options, %attrs);
    }
  );
}

sub _html_substr ($c, $html, $selector, $chars) {
  my $length = 0;
  state $dom = Mojo::DOM->new;
  my $first_tag = 1;
  my $last_tag  = 0;
  return c(split m|$/$/|, $html)->slice(0 .. 5)->map(
    sub($txt) {
      return '' if $last_tag;
      $length += length($txt);
      if ($length >= $chars) {
        $last_tag = 1;
        return
          '<p>'
          . substr($txt, 0, $first_tag ? $chars : $length - $chars) . '…</p>';
      }
      $first_tag = 0;
      return '<p>' . $txt . '</p>' . $/;
    }
    )->join('')
    unless $html =~ /<\w/;

  return $dom->parse($html)->find($selector)->slice(0 .. 5)->map(
    sub($el) {
      return '' unless $el;
      return '' if $last_tag;
      my $txt = $el->all_text;
      $length += length($txt);
      if ($length >= $chars) {
        $last_tag = 1;
        return
          tag_to_html($el->tag, %{$el->attr},
                 substr($txt, 0, $first_tag ? $chars : $length - $chars) . '…');
      }
      $first_tag = 0;
      return tag_to_html($el->tag, %{$el->attr}, $txt) . $/;
    }
  )->join('');
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
implements some additional helpers. L<Slovo::Plugin::DefaultHelpers> and
Slovo::Plugin::TagHelpers are loaded unconditionally after all other mandatory
for Slovo plugins.


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

=head2 html_substr

   %= html_substr($писанѥ->{teaser}//$писанѥ->{body}, 'p,blockquote', 225);

Parameters: C<$c, $html, $selector, $chars>

Get C<all_text> for each C<$selector> from C<$html> and does
L<substr|perlfunc/substr> on the last so the total characters in the produced output
are not more than C<$chars>. Starts from the first character in the first
matched C<$selector>. In case the C<$html> is simple text, produces
C<E<lt>pE<gt>> elements.

=head1 METHODS

The usual method is implemented.

=head2 register

Calls the parent's register if needed and registers additional helpers in Slovo application.


=head1 SEE ALSO

L<Mojolicious::Plugin::TagHelpers>, L<Slovo::Plugin::DefaultHelpers>

=cut

