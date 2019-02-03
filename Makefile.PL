use 5.020000;
use ExtUtils::MakeMaker;
use strict;
use warnings;
use utf8;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $module_file = 'lib/Slovo.pm';
my $git_url     = 'https://github.com/kberov/Slovo';
my $PREREQ_PM   = {
  'Authen::SASL'                        => '2.16',
  'Class::Method::Modifiers'            => '2.12',
  'Cpanel::JSON::XS'                    => '4.08',
  'Minion::Backend::SQLite'             => '4.002',
  'Mojo::SQLite'                        => '3.001',
  'Mojolicious'                         => '8.12',
  'Mojolicious::Plugin::PODViewer'      => '0.002',
  'Mojolicious::Plugin::Authentication' => '1.32',
  'Mojolicious::Plugin::OpenAPI'        => '2.00',
  'Mojolicious::Plugin::PODViewer'      => '0.002',
  'Mojolicious::Plugin::RoutesConfig'   => '0.05',
  'Net::SMTP'                           => '3.11',
  'Role::Tiny'                          => '2.000006',
  'EV'                                  => '4.22'
};

if ($ENV{TEST_AUTHOR}) {
  $PREREQ_PM = {
    %$PREREQ_PM,
    'Test::Pod'           => '1.52',
    'Test::Perl::Critic'  => '1.04',
    'Perl::Critic'        => '1.132',
    'Test::CheckManifest' => '1.33',
    'Test::PerlTidy'      => '20130104'
  };
}

WriteMakefile(
  NAME          => 'Slovo',
  VERSION_FROM  => $module_file,                                     # finds \$VERSION
  AUTHOR        => 'Красимир Беров (berov@cpan.org)',
  ABSTRACT_FROM => $module_file,
  LICENSE       => 'artistic_2',
  PREREQ_PM     => $PREREQ_PM,
  TEST_REQUIRES => {},
  test          => {TESTS => 't/*.t'},
  EXE_FILES     => ['script/slovo'],
  clean            => {FILES => '*.conf Slovo-* READM* lib/Slovo/resources/data/*.sqli*'},
  MIN_PERL_VERSION => '5.020000',
  META_MERGE       => {
    dynamic_config => 0,
    'meta-spec'    => {version => 2},
    no_index       => {directory => ['t']},
    prereqs        => {runtime => {requires => {perl => '5.020000'}}},
    resources      => {
      bugtracker => {web => "$git_url/issues"},
      homepage   => $git_url,
      license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
      repository => {type => 'git', url => "$git_url.git", web => $git_url,},
    },
  },
);


sub MY::postamble {
  my $preop          = qq 'podselect $module_file > README.pod;';
  my @perltidy_files = qw(script/slovo Makefile.PL);
  my $options        = {
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
\tperltidy -pro=.perltidyrc @perltidy_files
TARGETS
}

__END__

=encoding utf8

=head1 NAME

Makefile.PL for the Slovo project

=head1 SYNOPSIS

Some commands;

Install

    $ INSTALL_BASE=~/opt/slovo && rm -rf $INSTALL_BASE && make distclean; \
    perl Makefile.PL INSTALL_BASE=$INSTALL_BASE && make && make test && make install \
    && $INSTALL_BASE/bin/slovo

Start the server and open a browser

    $ daemon -l http://*:8080 & sleep 1 exo-open http://localhost:8080

Build Makefile even directly in vim

    !perl Makefile.PL

When you want to add new files to the ditribution

    make manifest

Beautify your code

    make perltidy

Re-generate README and README.POD

    make readme

=cut

