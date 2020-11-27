package Slovo::Plugin::MojoDBx;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

sub register ($self, $app, $conf = {}) {
  $conf = $self->_check_config($app, $conf);
  my $adaptor_class = "Mojo::$conf->{adaptor}";
  my $log           = $app->log;

  # $log->debug("Loading $adaptor_class");
  $app->load_class($adaptor_class);    # or Mojo::Pg, or Mojo::Mysql
  my $dbx;
  $app->helper(
    dbx => sub {
      return $dbx if ref $dbx eq $adaptor_class;
      $dbx = $adaptor_class->new($conf->{new});
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
      $dbx->auto_migrate($conf->{auto_migrate})
        ->max_connections($conf->{max_connections});
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

# Check configuration and set defaults.
sub _check_config ($self, $app, $conf) {
  $conf->{adaptor} //= 'SQLite';
  $conf->{adaptor} =~ /^SQLite|Pg|mysql$/
    || croak(
    '"adaptor" is a mandatory option! ' . 'Please use one of "SQLite", "Pg" or "mysql"!');
  my $home      = $app->home;
  my $mode      = $app->mode;
  my $moniker   = $app->moniker;
  my $resources = $app->resources;

  # Prefer data/slovo.$mode.sqlite over
  # lib/Slovo/resourcesdata/slovo.$mode.sqlite
  $conf->{new}
    //= (-d $home->child('data')
    ? $home->child("data/$moniker.$mode.sqlite")->to_string
    : $resources->child("data/$moniker.$mode.sqlite")->to_string);
  $conf->{sql_debug} //= 0;    #0|1|2|3|4|5
  $conf->{sql_debug} =~ /^[0-5]$/
    || croak("sql_debug must be an integer with value from 0 to 5!");

  $conf->{on_connection} //= [
    'PRAGMA synchronous = OFF', 'PRAGMA foreign_keys = ON',
    'PRAGMA cache_size = 80000',    #80M cache size

    #      sub($dbh) {
    #        $app->log->debug('SQLite version: '
    #                  . $dbh->selectrow_arrayref('select sqlite_version()')->[0]);
    #        # $dbh->{TraceLevel} = "3|SQL";
    #      }
  ];
  ref $conf->{on_connection} eq 'ARRAY'
    || croak('on_connection must be an ARRAY reference');

  $conf->{max_connections} //= 3;
  $conf->{auto_migrate}    //= 1;
  $conf->{migration_file}  //= $resources->child("data/migrations.sql")->to_string;
  $conf->{tables}          //= ['users', 'groups', 'domove', 'stranici', 'celini'];
  ref $conf->{tables} eq 'ARRAY'
    || croak('on_connection must be an ARRAY reference of table names,'
      . ' e.g. [qw(users groups ...)]');
  return $conf;
}
1;

=encoding utf8

=head1 NAME

Slovo::Plugin::MojoDBx - load and use Mojo::Pg/mysql/SQLite

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
about any code in your application as long as L<Mojo::Pg>, L<Mojo::mysql>,
L<Mojo::SQLite> or Mojo::WhateverDB have compatible APIs. B<For now some of our
SQL queries are still SQLite specific, but there is a plan to generalise them
or add the corresponding queries for Pg and mysql so they will be used
transparantly depending on the loaded L</adaptor>>.  Currently this plugin is
part of Slovo, but it can be easily moved to the Mojo::Plugin namespace if
there is positive feedback about that.

=head1 CONFIGURATION

The folowing options are currently supported. They basically get the data
needed for the most common steps of setting up database adaptors in
Mojolicious. All options have default values as if L<Mojo::SQLite> is used.

=head2 adaptor

The specific part of the name of a known database adaptor  - SQLite for
Mojo::SQLite, Pg for Mojo::Pg, etc. This adaptor will be loaded via
L<Slovo/load_class>.

=head2 migration_file

Full path to file which will be used for migrations.
Default value: C<SQLite>.

=head2 new

Anything that the  adaptor constructor would accept.
Default value:

    # Prefer data/slovo.$mode.sqlite over
    # lib/Slovo/resourcesdata/slovo.$mode.sqlite
    (-d $home->child('data')
    ? $home->child("data/$moniker.$mode.sqlite")->to_string
    : $resources->child("data/$moniker.$mode.sqlite")->to_string);

See also L<Mojo::SQLite/new> or L<Mojo::Pg/new>, or L<Mojo::mysql/new>.

=head2 on_connection

Array of SQL statements or code referneces. Some Perl or SQL code which you
want to execute every time the application conects to the database. See
L</SYNOPSIS>.


=head2 sql_debug

This plugin uses L<DBI/Callbacks> to log the produced SQL for debugging
purposes. A positive integer is used for L<perlfunc/caller> to report which
method produced this SQL. A value of C<0> disables SQL debugging and usually
C<4> or C<5> is useful. Allowed values are C</^[0-5]$/> The value represents
the number of callframes to skip when reporting the calling subroutine.
Default value: 0

=head2 max_connections

Integer. Default value: 3

=head2 auto_migrate

Boolean. Default value: 1

=head2 migration_file

Path to migration file.
Default value:

$resources->child("data/migrations.sql")->to_string

=head2 tables

Tables for which to be generated helpers. Each table name becomes a helper.
(e.g. C<users> becomes C<$c-E<gt>users> ot C<$app-E<gt>users>). Note that it is
expected that the respective model class to be instantiated already exists f.e.
L<Slovo::Model::Users> for the table C<users>. These classes can be initially
generated using L<Mojolicious::Command::Author::generate::resources>.
Default value: C<['users', 'groups', 'domove', 'stranici', 'celini']>

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


