package Slovo::Command::Author::inflate;
use Mojo::Base 'Mojolicious::Command::Author::inflate', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

use Mojo::Loader qw(data_section file_is_binary);
use Mojo::Util qw(encode getopt);

has description => 'Inflate embedded files to real files';
has usage       => sub { shift->extract_usage };

sub run ($self, @args) {

  getopt \@args,
    'home=s' => \(my $home = ''),
    ;
  $home = $home ? path($home) : $self->app->home;

  # Find all embedded files
  my %all;
  my $app = $self->app;
  for my $class (@{$app->renderer->classes}, @{$app->static->classes}) {
    for my $name (keys %{data_section $class}) {
      my $data = data_section $class, $name;
      $data = encode 'UTF-8', $data unless file_is_binary $class, $name;
      $all{$name} = $data;
    }
  }

  # Turn them into real files
  for my $name (grep {/\.\w+$/} keys %all) {
    my $prefix = $name =~ /\.\w+\.\w+$/ ? 'templates' : 'public';
    $self->write_file($home->child("$prefix/$name"), $all{$name});
  }
}

1;

=encoding utf8

=head1 NAME

Slovo::Command::Author::inflate - Inflate embedded files to domains or application folders

=head1 SYNOPSIS

  Usage: slovo inflate [OPTIONS]

  bin/slovo inflate
  bin/slovo inflate --home domove/localhost/

  Options:
    -h, --help          Show this summary of available options
        --home <path>   Path to home directory of your application or domain,
                        defaults to the value of MOJO_HOME or auto-detection.

=head1 DESCRIPTION

L<Slovo::Command::Author::inflate> turns templates and static files embedded in
the C<__DATA__> sections of your application into real files.
It is a slightly modified version of L<Mojolicious::Command::Author::inflate>.


=head1 ATTRIBUTES

L<Slovo::Command::Author::inflate> inherits all attributes from
L<Mojolicious::Command::Author::inflate> and implements the following new ones.

=head2 description

  my $description = $inflate->description;
  $inflate        = $inflate->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $inflate->usage;
  $inflate  = $inflate->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Slovo::Command::Author::inflate> inherits all methods from
L<Mojolicious::Command::Author::inflate> and implements the following new ones.

=head2 run

  $inflate->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Slovo>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
