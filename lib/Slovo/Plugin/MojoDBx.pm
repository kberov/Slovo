package Slovo::Plugin::MojoDBx;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

sub register ($self, $app, $conf) {
  $conf->{adaptor}
    || croak(  '"adaptor" is a mandatory option! '
             . 'Please use one of "SQLite", "Pg" or "mysql"!');
  my $adaptor_class = "Mojo::$conf->{adaptor}";
  my $log           = $app->log;
  $log->debug("Loading $adaptor_class");
  $app->load_class("Mojo::$conf->{adaptor}");    # or Mojo::Pg, or Mojo::Mysql
  my $helper = $conf->{helper} // 'dbx';

  $app->helper(
    $helper => sub {
      my $dbx = $adaptor_class->new($conf->{new});
      $dbx->on(
        connection => sub ($dbx, $dbh) {
          for my $sql_or_code (@{$conf->{on_connection} // []}) {
            $dbh->do($sql_or_code) unless ref $sql_or_code;
            $sql_or_code->($dbh) if ref $sql_or_code eq 'CODE';
          }
        }
      );

      my $home = $app->home->realpath->to_string;
      if ($conf->{sql_debug}) {
        $dbx->db->dbh->{Callbacks} = {
          prepare => sub {
            my ($dbh, $query, $attrs) = @_;
            my ($package, $filename, $line, $subroutine)
              = caller($conf->{sql_debug});
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
    }
  );


# Generated resources
# ./script/slovo generate resources -D dbx -t "groups,users,domove,stranici,celini" \
#   -T lib/Slovo/resources/templates --api_dir lib/Slovo/resources
# helpers for most tables
  for my $t (@{$conf->{tables} // []}) {
    my $T     = Mojo::Util::camelize($t);
    my $class = "Slovo::Model::$T";
    $app->load_class($class);
    $app->helper(
      $t => sub ($c) {
        my $self = $class->new(dbx => $c->dbx, c => $c);
        Scalar::Util::weaken $self->{c};
        return $self;
      }
    );
  }
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Plugin::MojoDBx - switch between Mojo::Pg/mysql/SQLite

=head1 SYNOPSIS

  $app->plugin(
    MojoDBI => {
      adaptor   => 'SQLite',    # Load Mojo::SQLite or 'mysql', or 'Pg'
      new => $app->resources->child("data/$moniker.$mode.sqlite"), 
      helper => 'dbx',       # instead of 'pg', 'mysql' or 'sqlite'
      on_connection => [
                        'PRAGMA synchronous = OFF',
                        'PRAGMA journal_mode=WAL',
                        'PRAGMA foreign_keys = ON',
                        sub($dbh) {
                            # do something after DBI connects
                            }
                       ],
      sql_debug       => 4,  # how many callframes to skip..(0 means 'no debug')
      max_connections => 3,
      migration_files =>
        [$app->home->child('sql/one.sql'), $app->home->child('sql/two.sql')]
        tables => [qw(users groups pages content)]
      ,                      # Tables to load models and generate helpers for
               }
              );

=head1 DESCRIPTION

Slovo::Plugin::MojoDBI allows you to switch from using one Mojo database
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
L<Mojo::Loader/load_class>.

=head2 adaptor_attributes

Array reference of hash referenses. See L<Mojo::Pg/ATTRIBUTES>. Keys will be
called as setters and the values will be passed as arguments.
=head2 dsn

Another way to specify database connection. See the corresponding documentation.

=head2 helper

The helper name which you will use everywhere in your controllers to invoke
database functionality. Common names are C<sqlite>, C<pg>, C<mysql>. Having a
common name will allow you to easily switch from SQLite to mysql for example as
your user-base grows. Defaults to C<dbx>.

=head2 migration_files

Array reference of full paths to files which will be used for migrations.

=head2 new

Mandatory. Anything that the constructor would accept.

=head2 on_connection

Array of SQL statements or code referneces. Some Perl or SQL code which you want to execute every time the application
conects to the database. See L</SYNOPSIS>.


=head2 sql_debug

This plugin uses L<DBI/Callbacks> to log the produced SQL for debugging
purposes. A positive integer is used for L<perlfunc/caller> to report which
method produced this SQL. A value of C<0> disables SQL debugging and usually
C<4> and above is useful. The value is the number of callframes to skip when
reporting the calling subroutine.


=head2 tables

Tables for which to be generated helpers. Each table name is camelized and
this is the name of the new helper for that table (e.g. C<users> becomes
C<Users>).

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

L<Mojo::Pg>, L<Mojo::mysql>, L<Mojo::SQLite>

=cut


