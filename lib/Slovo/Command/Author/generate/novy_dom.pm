package Slovo::Command::Author::generate::novy_dom;
use Mojo::Base 'Slovo::Command', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Mojo::File 'path';
use Mojo::Util qw(getopt class_to_path dumper sha1_sum encode);
use Mojo::Collection 'c';

has description => 'Generate database records, files and pages for a new domain';
has usage       => sub { shift->extract_usage };
has count       => 0;
has owner       => sub {
  $_[0]->app->users->find_where({login_name => 'foo'});
};
has [qw(skip_qr refresh_qr dom)] => undef;

sub run ($self, @args) {
  my $app = $self->app;
  getopt \@args,
    'n|name=s'    => \(my $name),
    'o|owner=s'   => \(my $owner = $self->owner->{login_name}),
    'a|aliases=s' => \(my $aliases),
    'c|chmod=s'   => \(my $chmod = oct(700)),
    's|skip=s'    => \(my $skip_qr),
    'r|refresh=s' => \(my $refresh_qr),
    ;

  # Display readable UTF-8
  # Redefine Data::Dumper::qquote() to do nothing
  ##no critic qw(TestingAndDebugging::ProhibitNoWarnings)
  no warnings 'redefine';
  local *Data::Dumper::qquote  = sub {qq["${\(shift)}"]};
  local $Data::Dumper::Useperl = 1;

  unless ($name) {
    say 'Domain name like example.com is a mandatory argument!' . $/;
    say $self->usage;
    return;
  }

  my $root = $app->config->{domove_root};
  say 'Domains folder: ' . $root;

  if ($owner eq $self->owner->{login_name}) {
    say "Assuming owner '$owner'.";
  }
  else {
    say "Owner is '$owner'.";
  }

  my $default_aliases = join(',', map {"$_.$name"} qw(www dev qa));
  unless ($aliases) {
    $aliases = $default_aliases;
    say 'Assuming domain aliases: ' . $aliases;
  }
  else {
    $aliases =~ s/\s+//g;
    $aliases = join(', ', split(/\,/, $aliases), $default_aliases);
    say 'Domain aliases: ' . $aliases;
  }

  unless (defined $skip_qr) {
    say 'Will not skip any file.';
  }
  else {
    say "Will skip files matching '$skip_qr'.";
    $self->skip_qr($skip_qr);
  }

  unless (defined $refresh_qr) {
    say 'Will not refresh any file.';
  }
  else {
    say "Will refresh files matching '$refresh_qr'.";
    $self->refresh_qr($refresh_qr);
  }

  $self->create_dir($root)->chmod_file($root, $chmod)->create_dir("$root/$name")
    ->chmod_file("$root/$name", $chmod);

  # copy default static files and templates
  $self->_copy_resourses_to("$root/$name", $chmod);

  # create and update records in database unless refreshed
  $self->_create_domain($name, $aliases)->_create_pages()->_update_admin()
    unless defined $self->refresh_qr;
  return $self;
}

sub _copy_resourses_to ($self, $to, $chmod) {
  my $from = path($INC{class_to_path('Slovo')})->sibling('Slovo/resources');

  my $from_public = "$from/public";
  my $to_public   = "$to/public";
  path($from_public)
    ->list_tree->each(sub { _copy_to($self, $from_public, @_, $to_public, $chmod) });

  my $from_tpl = "$from/templates";
  my $to_tpl   = "$to/templates";
  path($from_tpl)
    ->list_tree->each(sub { _copy_to($self, $from_tpl, @_, $to_tpl, $chmod) });
  say "  " . $self->count . " files created in $to." if $self->count;
  return;
}

sub _copy_to ($self, $from, $f, $i, $to, $chmod) {
  my $skip_qr    = $self->skip_qr;
  my $refresh_qr = $self->refresh_qr;
  my $copy       = $to . '/' . ($f =~ s/$from\///r);

  return if defined $skip_qr && $copy =~ /$skip_qr/;

  if (defined $refresh_qr && $copy =~ /$refresh_qr/ && -e $copy) {
    path($copy)
      ->remove_tree({keep_root => 1, verbose => 1, safe => 1, error => \(my $err)});
    _handle_remove_err($err);
  }
  return $self->create_dir($copy)->chmod_file($copy, $chmod) if -d $f;
  if (-f $f) {
    my $parent = path($copy)->dirname;
    $self->create_dir($parent)->chmod_file($parent, $chmod) unless -d $parent;
    unless (-f $copy) {
      $f->copy_to($copy) && say "  [write] $copy";
      $self->count($self->count + 1);
    }
    else {
      say "  [exist] $copy";
    }
  }
  return;
}

sub _handle_remove_err($err) {
  if ($err && @$err) {
    for my $diag (@$err) {
      my ($file, $message) = %$diag;
      if ($file eq '') {
        say "general error: $message";
      }
      else {
        say "problem unlinking $file: $message";
      }
    }
  }
  return;
}

# returns the id of the created domain
sub _create_domain ($self, $name, $aliases) {
  say 'Creating record for domain ' . $name;
  my $domove = $self->app->domove;
  my $dom    = {
    domain      => $name,
    aliases     => $aliases,
    site_name   => uc $name,
    description => "Великият нов дом $name…",
    owner_id    => $self->owner->{id},
    group_id    => $self->owner->{group_id},
    published   => 2
  };
  say "Will create domain with the following data." . dumper($dom);
  my $id = $domove->add($dom);
  $self->dom($domove->find($id));
  return $self;
}

sub _create_pages ($self) {
  my $time = time;
  my $dom  = $self->dom;
  say "Creating pages in domain $dom->{domain}…";
  my $common_data = {
    language    => 'bg-bg',
    published   => 2,
    dom_id      => $dom->{id},
    data_format => 'html',
    user_id     => $self->owner->{id},
    group_id    => $self->owner->{group_id},
    changed_by  => $self->owner->{id},
    tstamp      => $time,
    start       => $time,
  };

  my $pages = [{
      # this is the root page
      alias     => 'коренъ',
      title     => 'Добре дошли!',
      page_type => 'коренъ',
      body      => "<p>Добре сте ни дошли у $dom->{site_name}.</p>"
        . '<p>Променете съдържанието по ваше усмотрение.</p>',
      permissions => 'drwxr-xr-x',
      %$common_data,
    },
    {
      # this page lives under the root page
      alias     => 'ѿносно',
      title     => 'Ѿносно',
      page_type => 'обичайна',
      body      => "<p>Относно, мѣстото $dom->{site_name}, "
        . 'собствениците и каквото друго се сетите.</p>'
        . '<p>Нѣкaкъв по-дълъг теѯт, който е тѣло на писанѥто.</p>',
      permissions => 'rwxr-xr-x',
      %$common_data,
    }];
  my $app     = $self->app;
  my $root_id = 0;
  for my $p (@$pages) {
    $p->{pid} = $root_id;
    my $id = $app->stranici->add($p);
    $root_id ||= $id;
  }
  return $self;
}

sub _update_admin($self) {
  my $o = $self->owner;
  $o->{login_password} = c(
    split('', time),
    split('', '$[]{}_-%№€'),
    split('', 'абвгдежзийклмнопрстуфхцчшщьюяѥыѣѫѧѭѩѯꙃꙁѿ'))->shuffle->slice(0 .. 15)->join;

  my $stop_date = time + 3600;
  $self->app->users->save(
    $o->{id},
    {
      %$o,
      changed_by     => $o->{id},
      groups         => [1],
      disabled       => 0,
      stop_date      => $stop_date,
      login_password => sha1_sum(encode("utf8", "$o->{login_name}$o->{login_password}"))}
  );
  say "User $o->{login_name} is enabled till " . localtime($stop_date);
  say "The password is $o->{login_password}";

  return $self;
}
1;

=encoding utf8

=head1 NAME

Slovo::Command::Author::generate::novy_dom - Generate database records, files
and pages for a new domain

=head1 SYNOPSIS

    Usage: slovo generate novy_dom [OPTIONS]
    # Default values.
    slovo generate novy_dom -n example.com
    # Custom values.
    slovo generate novy_dom -n test.com -o краси
    # Do not copy templates nor css files.
    slovo generate novy_dom -n test.com -o краси -s '.*?\.(ep|css)$'
    # Refresh all copied templates from upgraded Slovo
    slovo generate novy_dom -n test.com -o краси -r '.*\.ep$'

  Options:
    -h, --help    Show this summary of available options
    -n, --name    Mandatory domain name - example.com.
    -a, --aliases Domain aliases. Quoted comma separataed string of domain
                  names. Defaults to "www.$name,dev.$name,qa.$name"
    -o, --owner   Username of the owner of this domain in the database.
                  Defaults to "foo".
    -c, --chmod   Octal number used as permissions for folders.
                  Defaults to 0700.
    -s, --skip    A regex. The files matching this regex will not be copied
                  to the domain folder.
    -r, --refresh A regex. Danger! The files matching this regex will be
                  removed, thus allowing files from upgraded Slovo to be copied
                  to the domain folders. This pattern is used after --skip
                  which takes precendence.
                  In case this option is passed, the domain will not be
                  recreated, pages will not be recreated and the admin user
                  will not be updated.

=head1 DESCRIPTION

L<Slovo::Command::Author::generate::novy_dom> will make a directory for a new
domain under C<$app-E<gt>config-E<gt>{domove_root}> (usually
C<$app-E<gt>home-E<gt>child('domove')>), copy static files and create the root
page, and a page "About" for the new domain. 

If the owner is not specified it will be set to 'foo'. The C<foo>'s password
will be changed to a random string and will be displayed to you.
The foo user will be enabled for one hour so you can login via the web
interface and change ownership of the domain and created pages to another user.
This is so for security reasons. 

If you use another owner, the owner must exist in the database. Please make
sure you have created an owner for the new domain. The owner will be made
C<admin> so it can manage the domain. It will be disabled after one hour for
security reasons. Set it's stop_date to 0 to prevent this. All
domain owners become admins. Please keep the number of admins low.

Sometimes you do not want all files to be copied and just use the common files
provided by Slovo or you want to make your own layouts, styles etc. In these
cases you can use the C<--skip> option.

Sometimes after upgrading Slovo to a new version you may want or need to update
the copied to your domain folder files. In this case you can use the
C<--refresh> option. Beware that C<novy_dom> will delete all the files matching
the provided pattern. I<It is recommended to use some version control system
like Git for you folder C<domove> to avoid resetting your files by mistake.>

=head1 ATTRIBUTES

L<Slovo::Command::Author::generate::novy_dom> inherits all attributes from
L<Slovo::Command> and implements the following new ones.

=head2 description

  my $description = $novy_dom->description;
  $cpanify        = $novy_dom->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $novy_dom->usage;
  $cpanify  = $novy_dom->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Slovo::Command::Author::generate::novy_dom> inherits all methods from
L<Slovo::Command> and implements the following new ones.

=head2 run

  $novy_dom->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Slovo>,L<Mojolicious::Command>
L<Mojolicious::Guides::Cookbook/Adding-commands-to-Mojolicious>,
L<Mojolicious::Guides>, L<https://слово.бг>.

=cut

__DATA__
