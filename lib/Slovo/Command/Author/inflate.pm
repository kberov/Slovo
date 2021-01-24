package Slovo::Command::Author::inflate;
use Mojo::Base 'Mojolicious::Command::Author::inflate', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

use Mojo::File qw(path);
use Mojo::Loader qw(data_section file_is_binary);
use Mojo::Util qw(encode getopt dumper);

has description => 'Inflate embedded files to domains or application folders';
has usage       => sub {
  $_[0]->extract_usage
    . $/
    . 'Inflatable classes:'
    . $/
    . '  For templates/:' . "$/\t"
    . join("$/\t", @{$_[0]->app->renderer->classes})
    . $/
    . '  For public/:' . "$/\t"
    . join("$/\t", @{$_[0]->app->static->classes})
    . $/;
};

my sub _extract_name_from_class ($name, $class, $templates, $public) {
  if ($name =~ /\.\w+\.\w+$/ && !$templates) { return; }
  if ($name !~ /\.\w+\.\w+$/ && !$public)    { return; }
  my $data = data_section $class, $name;
  $data = encode 'UTF-8', $data unless file_is_binary $class, $name;
  return $data;
}

sub run ($self, @args) {

  getopt \@args,
    'path=s'      => \(my $path),
    't|templates' => \(my $templates),
    'p|public'    => \(my $public),
    'class=s@'    => \(my $classes = []),
    ;

  # behave like parent command
  if (!$path && !$templates && !$public && !@$classes) {
    return $self->SUPER::run();
  }
  $path = $path ? path($path) : $self->app->home;
  my $app = $self->app;
  @$classes = split(/,\s?/, join(',', @$classes)) if @$classes;
  $classes  = [
    $templates ? (@{$app->renderer->classes}) : (),
    $public    ? (@{$app->static->classes})   : ()]
    unless @$classes;

  # Find embedded files
  my %all;
  for my $class (@$classes) {
    for my $name (keys %{data_section $class}) {
      my $data = _extract_name_from_class($name, $class, $templates, $public);
      $all{$name} = $data if $data;
    }
  }
  STDERR->say("Nothing to inflate!" . $/, $self->usage) if !keys %all && !$self->quiet;

  # Turn them into real files
  for my $name (grep {/\.\w+$/} keys %all) {
    my $prefix = $name =~ /\.\w+\.\w+$/ ? 'templates' : 'public';
    $self->write_file($path->child("$prefix/$name"), $all{$name});
  }
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Command::Author::inflate - Inflate embedded files to domains or application folders

=head1 SYNOPSIS

  Usage: bin/slovo inflate [OPTIONS]

  bin/slovo inflate   # Same as `mojo inflate`!

  bin/slovo inflate --class Slovo::Themes::Malka -t \
    --path domove/localhost/templates/themes/malka
  bin/slovo inflate --class Slovo::Themes::Malka -p \
    --path domove/localhost/public

  Options:
    -h, --help            Show this summary of available options

    --path <path>         Path where the files will be inflated.
                          Defaults to the value of MOJO_HOME or auto-detection.

    --class <Class::Name> From which class only to inflate files. Can be
                          repeated several time for several different classes or
                          passed as a comma-separated string.
                          No class by default.

    --public|p <bool>     Should the static files be inflated? No, by default.

    --templates|t <bool>  Should the templates be inflated? No, by default.

    If no options are provided, the command behaves like `mojo inflate`.

=head1 DESCRIPTION

L<Slovo::Command::Author::inflate> turns templates and static files embedded in
the C<__DATA__> sections of your application into real files.
It is an extended version of L<Mojolicious::Command::Author::inflate>.


=head1 ATTRIBUTES

L<Slovo::Command::Author::inflate> inherits all attributes from
L<Mojolicious::Command::Author::inflate> and implements the following.

=head2 description

  my $description = $inflate->description;
  $inflate        = $inflate->description('Foo');

Short description of this command, used for the command list.

=head1 METHODS

L<Slovo::Command::Author::inflate> inherits all methods from
L<Mojolicious::Command::Author::inflate> and implements the following new ones.

=head2 run

  $inflate->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Mojolicious::Command::Author::inflate>
L<Mojolicious::Guides::Growing/WELL-STRUCTURED-APPLICATION>,
L<Mojolicious::Guides::Rendering/Bundling assets with plugins>,
L<Mojolicious::Renderer>,
L<Slovo>, 
L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
