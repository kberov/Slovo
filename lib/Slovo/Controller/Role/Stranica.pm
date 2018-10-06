package Slovo::Controller::Role::Stranica;
use Mojo::Base -role, -signatures;
use Mojo::File 'path';
use Mojo::ByteStream 'b';
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

around execute => sub ($execute, $c) {
  state $cache_pages = $c->config('cache_pages');
  state $list_columns
    = $c->openapi_spec('/paths/~1страници/get/parameters/4/default');
  state $not_found_id   = $c->not_found_id;
  state $not_found_code = $c->not_found_code;
  return 1
    if $cache_pages && !$c->is_user_authenticated && $c->_render_cached_page();
  my $preview = $c->is_user_authenticated && $c->param('прегледъ');
  my $alias   = $c->stash->{'страница'};
  my $l       = $c->language;
  my $user    = $c->user;

  my $str    = $c->stranici;
  my $domain = $c->host_only;
  my $page   = $str->find_for_display($alias, $user, $domain, $preview);

  # Page was found, but with a new alias.
  return $c->_go_to_new_page_url($page, $l)
    if $page && $page->{alias} ne $alias && !$c->stash->{'цѣлина'};

  # Give up - page was not found.
  $page //= $str->find($not_found_id);
  $page->{is_dir} = $page->{permissions} =~ /^d/;
  $c->stash($page->{template} ? (template => $page->{template}) : ());
  my $celini
    = $c->celini->all_for_display_in_stranica($page, $user, $l, $preview);

  #These are always used so we add them to the stash earlier.
  $c->stash(
    'страница'   => $page->{alias},
    celini       => $celini,
    domain       => $domain,
    list_columns => $list_columns,
    page         => $page,
    preview      => $preview,
    user         => $user,

    # data_type to template name
    d2t => {
            'белѣжка' => '_beleyazhka',
            'въпросъ' => '_wyprosy',
            'заглавѥ' => '_zaglawie',
            'книга'   => '_kniga',
            'писанѥ'  => '_pisanie',
            'цѣлина'  => '_ceyalina',
            'ѿговоръ' => '_otgowory'
           },
  );

  if ($page->{id} == $not_found_id) {
    $c->stash(breadcrumb => []);
    $c->stash(status     => $not_found_code);
    return $c->render();
  }
  $c->stash(breadcrumb => $str->breadcrumb($page->{id}, $l));
  my $ok = $execute->($c, $page, $user, $l, $preview);

  # Cache this page on disk if user is not authenticated.
  $c->_cache_page()
    if $cache_pages && $c->res->is_success && !$c->is_user_authenticated;
  return $ok;
};

sub _go_to_new_page_url ($c, $page, $l) {

  # https://tools.ietf.org/html/rfc7538#section-3
  my $status = $c->req->method =~ /GET|HEAD/i ? 301 : 308;
  $c->res->code($status);
  return $c->redirect_to(
           'страница_с_ѩꙁыкъ' => {'страница' => $page->{alias}, 'ѩꙁыкъ' => $l});
}

my $cached    = 'cached';
my $cacheable = qr/\.html$/;

sub _render_cached_page($c) {
  my $url_path = $c->req->url->path->canonicalize->leading_slash(0)->to_route;
  return unless $url_path =~ $cacheable;
  my $file = path($c->app->static->paths->[0], $cached, $url_path);
  return $c->render(text => b($file->slurp)->decode) if -f $file;
  return;
}

sub _cache_page($c) {
  my $url_path = $c->req->url->path->canonicalize->leading_slash(0)->to_route;
  return unless $url_path =~ $cacheable;
  my $file = path($c->app->static->paths->[0], $cached, $url_path);
  $file->dirname->make_path({mode => oct(700)});

  # This file will be deleted automatically when the page or its заглавѥ is
  # changed.
  return $file->spurt($c->res->body =~ s/(<html[^>]+>)/$1<!-- $cached -->/r);
}

# Delete cached pages
# TODO: Execute this in a subprocess as $cache_dir->remove_tree may be slow on
# large directories.
# See http://localhost:3000/perldoc/Mojolicious/Guides/Cookbook#Subprocesses
my $clear_cache = sub ($action, $c) {

  state $app   = $c->app;
  state $droot = $app->config('domove_root');
  my $id = $c->param('id');
  return $action->($c) unless $id;    # something is wrong
  my $cll       = $c->stash('controller');
  my $domain    = '';
  my $cache_dir = '';

  #it is a page
  if ($cll =~ /stranici$/i) {
    my $dom_id = $c->stranici->find($id)->{dom_id};
    $domain = $c->domove->find($dom_id)->{domain};
  }

  # it is a celina
  elsif ($cll =~ /celini$/i) {
    my $page_id = $c->celini->find($id)->{page_id};
    my $dom_id  = $c->stranici->find($page_id)->{dom_id};
    $domain = $c->domove->find($dom_id)->{domain};
  }

  my $ok = $action->($c);
  return unless $ok;

  $cache_dir = path $droot, $domain, 'public', $cached;

  $c->debug('REMOVING ' . $cache_dir);
  $cache_dir->remove_tree;
  return $ok;
};

around update => $clear_cache;
around remove => $clear_cache;

sub b64_images_to_files ($c, $name) {
  my $v = $c->validation->output;
  return if (($v->{data_format} // '') ne 'html');
  return unless ($v->{$name} =~ m|<img.+?src=['"]data\:.+?base64|mso);
  my $dom    = Mojo::DOM->new($v->{$name});
  my $images = $dom->find('img[src^="data:image/"]');
  state $paths = $c->app->static->paths;
  $images->each(
    sub ($img, $i) {
      my ($type, $b64) = $img->{src} =~ m|data:([\w/\-]+);base64\,(.+)$|;
      return unless $b64;
      my ($ext) = $type =~ m|/(.+)$|;
      my $stream = b($b64)->b64_decode;
      my $ipad = $i < 10 ? "0$i" : $i;
      my $src
        = path($paths->[0], 'img', $v->{alias} . "-$ipad.$ext")->spurt($stream);
      ($img->{src}) = $src =~ m|public(/.+)$|;

      # TODO: resize the image on disc according to 'with' and 'height'
      # attributes if available and keep resolution 96dpi. Save original image
      # as well as resized image. Use resized image in src attribute.
    }
  );
  $v->{$name} = $dom->to_string;
  return;
}

sub writable ($v, $name, $value, $c) {
  my $id = $c->param('id');

  # creating new record? ok
  return 1 if (!$id);
  my ($record_type) = ref($c) =~ m|(\w+)$|;
  $record_type = lc($record_type);
  my $m    = $c->$record_type;
  my $user = $c->user;           # current user
  my $old = $m->find_where({'id' => $id, %{$m->writable_by($user)}});
  state $log = $c->app->log;

  # not changing permissions? ok
  return 1 if ($old && ($old->{permissions} eq $value));

  if ($old) {
    if ($old->{user_id} != $user->{id}) {
      $v->error(
                writable => [
                             'not_owner',
                             "user_id: $old->{user_id} != $user->{id}",
                             "permissions: $old->{permissions} != $value"
                            ]
               );
      $log->error(  "failed to change mode of $record_type:"
                  . $c->dumper($v->error('writable'))
                  . __FILE__ . ':'
                  . __LINE__);
      return 0;
    }
  }

  #not writable $old
  $old = $m->find_where({'id' => $id, %{$m->readable_by($user)}});
  if ($old->{user_id} != $user->{id}) {
    $v->error(
              writable => [
                           'not_owner',
                           "user_id: $old->{user_id} != $user->{id}",
                           "permissions: $old->{permissions} != $value"
                          ]
             );
    $log->error(  "failed to change mode of $record_type:"
                . $c->dumper($v->error('writable'))
                . __FILE__ . ':'
                . __LINE__);
    return 0;
  }

  #new permissions
  state $rwx = qr/[r\-][w\-][x\-]/x;
  state $rx  = qr/^[ld\-]($rwx)($rwx)($rwx)$/x;
  my @writable = $value =~ $rx;

  #invalid permissions notation!
  if (!@writable) {
    $v->error(writable => ['invalid_notation', "permissions: '$value'"]);
    $log->error(  "invalid_notation '$value' for $record_type:"
                . __FILE__ . ':'
                . __LINE__);
    return 0;
  }

  # owner can change permissions in place
  if (   $writable[0] =~ /^$rwx$/
      || $writable[1] =~ /^$rwx$/
      || $writable[2] =~ /^$rwx$/)
  {
    $log->warn(  "Making the $record_type with id $old->{id}"
               . " not listable for group_id $old->{group_id}: $writable[1]")
      if $writable[1] eq '---';
    $log->warn(  "Making the $record_type with id $old->{id}"
               . " not listable for others: $writable[2]")
      if $writable[2] eq '---';
    return 1;
  }
  my %error = (
               writable => [
                            'unknown_not_writable',
                            {
                             from         => $old->{permissions},
                             to           => $value,
                             owner_id     => $old->{user_id},
                             current_user => $user->{id}
                            }
                           ]
              );

  #unknown error /untested conditions
  $v->error(%error);
  $log->error(  "unknown_not_writable $record_type:"
              . $c->dumper($v->error('writable'))
              . __FILE__ . ':'
              . __LINE__);
  return 0;
}

=encoding utf8

=head1 NAME

Slovo::Controller::Role::Stranica - common methods for Stranici and Celini


=head2 METHODS

In this role are implemented the following shared methods.

=head2 around execute

Wrapper around methods L<Slovo::Controller::Stranici/execute> and
L<Slovo::Controller::Celini/execute>. Most of the work for constructing the
page is done here so for L<Slovo::Controller::Stranici> is left only to render
everything put by this wrapper into stash. L<Slovo::Controller::Celini> in
addition has to find the specific celina to render.

To the wrapped methods are passed the parameters C<$page, $user, $language,
$preview>.  C<$page> is the current page with the заглавѥ celina in the current
$ѩꙁыкъ.  C<$user> is the current user. C<$language> is the current C<$ѩꙁыкъ>.
C<$preview>  is a boolean value - true if the current request is just a preview.
In preview mode C<permissions> and c<published> columns of the records in the
database are not respected.

Beside constructing the page, if there is a cached page or celina with the
requested url path, it is simply slurped and rendered for non autheticated
users.

After the rendering is done by the consuming classes, the constructed response
body is cached and saved on disk. On the next request by a guest user it is
simply rendered, as mentioned above.

Returns the result of C<$c-E<gt>render()>.


=head2 around remove

=head2 around update

In case a celina or a stranica is updated or removed, all cached pages on disk
are deleted. This may fell like small slowdown if you have thousands of cached
pages.


=head2 b64_images_to_files

  $c->b64_images_to_files('foo');

Cleans up a parameter from base64 images and updates it with path to extracted
images.

Expects that the value of the parameter with name 'foo' is a HTML string. Scans
it for C<img> tags wich contain base64 encoded image in their C<src> attribute.
Decodes the encoded values and saves them in files in the specific domain
public directory. The files are named after the alias of the record + count.
Example (Second image in the body of a celina record with alias 'hello'):
C<hello1.png>. Puts the URL path to the newly created file into the src
attribute (e.g. C</img/hello01.png>). The <src> attributes of the images are
replaced with the paths to the newly created files.

=head2 SEE ALSO

L<Slovo::Controller::Celini>, L<Slovo::Controller::Stranici>

=cut

1;

