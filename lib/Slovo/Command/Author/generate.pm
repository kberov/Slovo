package Slovo::Command::Author::generate;
use Mojo::Base 'Mojolicious::Command::Author::generate';

has description => 'Generate files and directories from templates';
has hint        => <<'EOF';

See 'slovo generate help GENERATOR' for more information on a specific
generator.
EOF
has message    => sub { shift->extract_usage . "\nGenerators:\n" };
has namespaces => sub { [__PACKAGE__] };

1;

=encoding utf8

=head1 NAME

Slovo::Command::Author::generate - Generator command

=head1 SYNOPSIS

  Usage: slovo generate GENERATOR [OPTIONS]

  Example:  slovo generate cgi_script -f index.cgi --cgi_mode productuion

=head1 DESCRIPTION

L<Slovo::Command::Author::generate> lists available generators.

This is a core command, that means it is always enabled and its code a good
example for learning to build new commands, you're welcome to fork it.

See L<Mojolicious::Commands/"COMMANDS"> for a list of commands that are
available by default in Mojolicious.

=head1 ATTRIBUTES

L<Slovo::Command::Author::generate> inherits all attributes from
L<Mojolicious::Command::Author::generate> and implements the following new
ones.

=head2 description

  my $description = $generator->description;
  $generator      = $generator->description('Foo');

Short description of this command, used for the command list.

=head2 hint

  my $hint   = $generator->hint;
  $generator = $generator->hint('Foo');

Short hint shown after listing available generator commands.

=head2 message

  my $msg    = $generator->message;
  $generator = $generator->message('Bar');

Short usage message shown before listing available generator commands.

=head2 namespaces

  my $namespaces = $generator->namespaces;
  $generator     = $generator->namespaces(['MyApp::Command::generate']);

Namespaces to search for available generator commands, defaults to
L<Slovo::Command::Author::generate>.

=head1 METHODS

L<Slovo::Command::Author::generate> inherits all methods from
L<Mojolicious::Commands> and implements the following new ones.

=head2 help

  $generator->help('app');

Print usage information for generator command.

=head1 SEE ALSO

L<Slovo>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
