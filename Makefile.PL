package Slovo;
use 5.026000;
use ExtUtils::MakeMaker 7.24;
use strict;
use warnings;
use utf8;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
my $module_file = 'lib/' . __PACKAGE__ . '.pm';
my $git_url     = 'https://github.com/kberov/Slovo';
my $PREREQ_PM   = {
  'Authen::SASL'                        => '2.16',
  'Class::Method::Modifiers'            => '2.13',
  'Cpanel::JSON::XS'                    => '4.25',
  'Minion::Backend::SQLite'             => '5.0.3',
  'Mojo::SQLite'                        => '3.004',
  'Mojolicious'                         => '9.02',
  'Mojolicious::Plugin::PODViewer'      => '0.006',
  'Mojolicious::Plugin::Authentication' => '1.32',
  'Mojolicious::Plugin::OpenAPI'        => '4.04',
  'Mojolicious::Plugin::RoutesConfig'   => '0.06',
  'Net::SMTP'                           => '3.11',
  'Role::Tiny'                          => '2.001004',
  'EV'                                  => '4.33'
};

if ($ENV{TEST_AUTHOR}) {
  $PREREQ_PM = {
    %$PREREQ_PM,
    'Test::Pod'          => '1.52',
    'Test::Perl::Critic' => '1.04',
    'Perl::Critic'       => '1.132',
    'Test::PerlTidy'     => '20130104'
  };
}

WriteMakefile(
  NAME               => __PACKAGE__,
  VERSION_FROM       => $module_file,
  AUTHOR             => 'Красимир Беров (berov@cpan.org)',
  ABSTRACT_FROM      => $module_file,
  LICENSE            => 'artistic_2',
  PREREQ_PM          => $PREREQ_PM,
  CONFIGURE_REQUIRES => {},
  BUILD_REQUIRES     => {'ExtUtils::MakeMaker' => '7.24'},
  TEST_REQUIRES      => {},
  test               => {TESTS => 't/*.t'},
  EXE_FILES          => ['script/slovo'],
  clean              => {FILES => '*.conf Slovo-* lib/Slovo/resources/data/*.sqli*'},
  MIN_PERL_VERSION   => '5.026000',
  META_MERGE         => {
    dynamic_config => 0,
    'meta-spec'    => {version   => 2},
    no_index       => {directory => ['t']},
    prereqs        => {runtime   => {requires => {perl => '5.026000'}}},
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
  my $perltidy_files = join '\\' . $/ . "\t ", @perltidy_files;
  return <<"TARGETS";
readme ::
\t$preop
dist : readme

perltidy ::
\tperltidy -pro=.perltidyrc \\
\t$perltidy_files

TARGETS
}

__END__

=encoding utf8

=head1 NAME

Makefile.PL for the Slovo project

=head1 SYNOPSIS

Some commands:

Set C<INSTALL_BASE>, remove old Slovo installation, make, test, install, create
data directory for sqlite database and run slovo to see available commands.

    INSTALL_BASE=~/opt/slovo && rm -rf $INSTALL_BASE && make distclean; \
    perl Makefile.PL INSTALL_BASE=$INSTALL_BASE && make && make test && make install \
    && $INSTALL_BASE/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});' \
    && $INSTALL_BASE/bin/slovo

Use cpanm to install or update into a custom location as self contained application and
run slovo to see how it's going

    # From metacpan. org
    export PREFIX=~/opt/slovo;
    cpanm -M https://cpan.metacpan.org -n --self-contained -l $PREFIX Slovo \
    $PREFIX/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});' \
    $PREFIX/bin/slovo

    # From the directory where you unpacked Slovo
    export PREFIX=~/opt/slovo;
    cpanm . -n --self-contained -l $PREFIX Slovo
    $PREFIX/bin/slovo eval 'app->home->child("data")->make_path({mode => 0700});'
    $PREFIX/bin/slovo

Start the development server and open a browser

    morbo ./script/slovo -l http://*:3000 & sleep 1 exo-open http://localhost:3000

Start the production server

    hypnotoad script/slovo
    # you will see something like the following:
    [2019-02-24 19:38:08.69754] [13570] [info] Listening at "http://127.0.0.1:9090"
    Server available at http://127.0.0.1:9090
    [2019-02-24 19:38:08.69804] [13570] [info] Listening at "http://[::1]:9090"
    Server available at http://[::1]:9090


Build Makefile even directly in vim

    !perl Makefile.PL

When you want to add new files to the ditribution

    make manifest

Beautify your code

    make perltidy

Re-generate README and README.pod

    make readme

=cut

