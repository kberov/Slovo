use 5.020000;
use ExtUtils::MakeMaker;
use strict;
use warnings;
use utf8;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $module_file = 'lib/Slovo.pm';
my $git_url     = 'https://github.com/kberov/Slovo';
WriteMakefile(
  NAME          => 'Slovo',
  VERSION_FROM  => $module_file,                        # finds \$VERSION
  AUTHOR        => 'Красимир Беров (berov@cpan.org)',
  ABSTRACT_FROM => $module_file,
  PREREQ_PM => {'Mojolicious' => '7.71', perl => '5.020001'},
  TEST_REQUIRES =>
    {'Mojo::SQLite' => '3.000', 'Mojolicious::Plugin::OpenAPI' => '1.25'},
  test       => {TESTS => 't/*.t'},
  EXE_FILES  => ['script/slovo'],
  clean      => {FILES => 'Slovo-* READM*'},
  META_MERGE => {
       dynamic_config => 0,
       'meta-spec'    => {version => 2},
       no_index       => {directory => ['t']},
       prereqs        => {runtime => {requires => {perl => '5.020000'}}},
       resources      => {
         bugtracker => {web => "$git_url/issues"},
         homepage   => $git_url,
         license => ['http://www.opensource.org/licenses/artistic-license-2.0'],
         repository => {type => 'git', url => "$git_url.git", web => $git_url,},
       },
  },
);


sub MY::postamble {
  my $preop = qq 'podselect $module_file > README.pod;';
  my @perltidy_files;
  my $options = {
    no_chdir => 1,
    wanted   => sub {
      push @perltidy_files, $_ if $_ =~ /\.(PL|pm|pl|t|conf)$/;
    }
  };
  File::Find::find($options, 'lib', 't');

  return <<"TARGETS";
readme ::
\t$preop
dist : readme

perltidy ::
\tperltidy Makefile.PL script/slovo @perltidy_files
TARGETS
}

__END__

=encoding utf8

=head1 SYNOPSIS

Some commands;

    $ INSTALL_BASE=~/opt/slovo && rm -rf $INSTALL_BASE && make distclean; \
    perl Makefile.PL INSTALL_BASE=$INSTALL_BASE && make && make test && make install \
    && $INSTALL_BASE/bin/slovo

    $ daemon -l http://*:8080 & sleep 1 exo-open http://localhost:8080

    # even directly in vim
    !perl Makefile.PL
    # when you want to add ne files to the ditribution
    make manifest
    make perltidy
    make readme

=cut

