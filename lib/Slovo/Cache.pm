package Slovo::Cache;
use Mojo::Base 'Mojo::Cache';

has cache      => sub { {} };
has key_prefix => '';
has max_keys   => 111;

sub new {
  my $self = shift->SUPER::new(@_);
  $self->{key_prefix} //= '';
  $self->{cache} ||= {};
  $self->{queue} ||= [];
  return $self;
}

## no critic qw(RequireArgUnpacking RequireFinalReturn)
sub get { $_[0]->{cache}{$_[0]->{key_prefix} . ($_[1] // '')} }

## no critic qw(ProhibitAmbiguousNames)
sub set {
  my ($self, $key, $value) = @_;
  $key = $_[0]->{key_prefix} . $key;
  return $self if not((my $max = $self->max_keys) > 0);

  my $cache = $self->{cache};
  my $queue = $self->{queue};
  delete $cache->{shift @$queue} while @$queue >= $max;
  push @$queue, $key unless exists $cache->{$key};
  $cache->{$key} = $value;

  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Cache - Naive in-memory cache

=head1 SYNOPSIS

  use Slovo::Cache;

  my $cache = Slovo::Cache->new(max_keys => 50, prefix=>'baz');
  $cache->set(foo => 'bar');
  my $foo = $cache->get('foo'); # bar

=head1 DESCRIPTION

L<Slovo::Cache> is a naive in-memory cache with size limits and key prefixes.
It is a modification of L<Mojo::Cache>. It can set a prefix to the keys. This
is how we cache templates to support different themes per domain.

=head1 ATTRIBUTES

L<Slovo::Cache> implements the following attributes.

=head2 key_prefix

The prefix which will be used for each key. Defaults to empty string. It is
reset in L<Slovo/around_dispatch> to set different namespace for cached
templates per domain.

=head2 max_keys

  my $max = $cache->max_keys;
  $cache  = $cache->max_keys(50);

Maximum number of cache keys, defaults to C<111>. Setting the value to C<0> will disable caching.

=head1 METHODS

L<Mojo::Cache> inherits all methods from L<Mojo::Base> and implements the following new ones.

=head2 get

  my $value = $cache->get('foo');

Get cached value.

=head2 set

  $cache = $cache->set(foo => 'bar');

Set cached value.

=head1 SEE ALSO

L<Slovo/around_dispatch>,
L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
