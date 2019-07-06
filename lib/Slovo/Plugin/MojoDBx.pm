package Slovo::Plugin::MojoDBx;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::Util 'deprecated';

sub register ($self, $app, $conf) {
  $conf->{adaptor}
    || croak(
    '"adaptor" is a mandatory option! ' . 'Please use one of "SQLite", "Pg" or "mysql"!');
  my $adaptor_class = "Mojo::$conf->{adaptor}";
  my $log           = $app->log;

  #$log->debug("Loading $adaptor_class");
  $app->load_class("Mojo::$conf->{adaptor}");    # or Mojo::Pg, or Mojo::Mysql
      # This should not be an option. Must be always 'dbx'.
  my $helper = $conf->{helper} // 'dbx';
  deprecated('"helper" config option is DEPRECATED! We always use "dbx".')
    if $conf->{helper};
  $app->helper(
    $helper => sub {
      my $dbx = $adaptor_class->new($conf->{new});
      $dbx->on(
        connection => sub ($dbx, $dbh) {
          for my $sql_or_code (@{$conf->{on_connection} // []}) {
            $dbh->do($sql_or_code) unless ref $sql_or_code;
            $sql_or_code->($dbh) if ref $sql_or_code eq 'CODE';
          }
        });

      my $home = $app->home->realpath->to_string;
      if ($conf->{sql_debug}) {
        $dbx->db->dbh->{Callbacks} = {
          prepare => sub {
            my ($dbh, $query, $attrs) = @_;
            my ($package, $filename, $line, $subroutine) = caller($conf->{sql_debug});
            $filename =~ s/$home[\/]?//;
            $log->debug("SQL from $subroutine in $filename:$line :\n$query\n");
            return;
          },
          execute => sub {
            $log->debug("Executing " . $_[0]->{Statement});
          }
        };
      }

      $dbx->migrations->from_file($conf->{migration_file});
      $dbx->auto_migrate($conf->{auto_migrate} // 0)
        ->max_connections($conf->{max_connections} // 3);
      return $dbx;
    });

# Generated resources
# ./script/slovo generate resources -D dbx -t "groups,users,domove,stranici,celini" \
#   -T lib/Slovo/resources/templates --api_dir lib/Slovo/resources
# helpers for most tables
  for my $t (@{$conf->{tables} // []}) {
    my $T     = Mojo::Util::camelize($t);
    my $class = "Slovo::Model::$T";
    $app->load_class($class);
    $app->helper(
      $t => sub($c) {
        my $m = $class->new(dbx => $c->dbx, c => $c);
        Scalar::Util::weaken $m->{c};
        return $m;
      });
  }
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::MojoDBx - switch between Mojo::Pg/mysql/SQLite

=head1 SYNOPSIS

  # in slovo.conf
  plugins => [
   #... Should be one of the first plugins
   {
    MojoDBx => {
      adaptor   => 'SQLite',
      new       => $db_file,
      sql_debug => 0,          #4,
      on_connection => [
        'PRAGMA synchronous = OFF', 'PRAGMA foreign_keys = ON',
        'PRAGMA cache_size = 80000',    #80M cache size

    #   sub($dbh) {
    #      $app->log->debug('SQLite version: '
    #                 . $dbh->selectrow_arrayref('select sqlite_version()')->[0]);
    #      # $dbh->{TraceLevel} = "3|SQL";
    #     }
                       ],
      max_connections => 3,
      auto_migrate    => 1,
      migration_file  => $rsc->child("data/migrations.sql")->to_string,

      # Which helpers for Models to load:
      # Slovo::Model::Users,Slovo::Model::Groups... etc.
      tables => ['users', 'groups', 'domove', 'stranici', 'celini'],
    }
   },
  #... Other plugins
  ],

=head1 DESCRIPTION

Slovo::Plugin::MojoDBx allows you to switch from using one Mojo database
adaptor to another without having to change your database helper name or just
about any code in your application as long as L<Mojo::Pg>,
L<Mojo::mysql>, L<Mojo::SQLite> or Mojo::WhateverDB have compatible APIs.
Currently this plugin is part of Slovo, but it can be easily moved to the
Mojo::Plugin namespace if there is positive feedback about that.

=head1 CONFIGURATION

The folowing options are currently supported. They basically get the data
needed for the most common steps of setting up database adaptors in
Mojolicious.

=head2 adaptor

The specific part of the name of a known database adaptor  - SQLite for
Mojo::SQLite, Pg for Mojo::Pg, etc. This adaptor will be loaded via
L<Slovo/load_class>.

=head2 migration_file

Full path to file which will be used for migrations.

=head2 new

Mandatory. Anything that the constructor would accept.

=head2 on_connection

Array of SQL statements or code referneces. Some Perl or SQL code which you
want to execute every time the application conects to the database. See
L</SYNOPSIS>.


=head2 sql_debug

This plugin uses L<DBI/Callbacks> to log the produced SQL for debugging
purposes. A positive integer is used for L<perlfunc/caller> to report which
method produced this SQL. A value of C<0> disables SQL debugging and usually
C<4> and above is useful. The value is the number of callframes to skip when
reporting the calling subroutine.


=head2 tables

Tables for which to be generated helpers. Each table name becomes a helper.
(e.g. C<users> becomes C<$c-E<gt>users> ot C<$app-E<gt>users>). Note that it is
expected that the respective model class to be instantiated already exists f.e.
L<Slovo::Model::Users> for the table C<users>. These classes can be initially
generated using L<Mojolicious::Command::Author::generate::resources>.

=head1 AUTHOR

    Красимир Беров
    CPAN ID: BEROV
    berov ат cpan точка org
    http://i-can.eu

=head1 COPYRIGHT

This program is free software licensed under the Artistic License 2.0.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

L<Mojo::Pg>, L<Mojo::mysql>, L<Mojo::SQLite>,
L<Mojolicious::Command::Author::generate::resources>.

=cut


