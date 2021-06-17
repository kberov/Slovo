package Slovo::Controller::Role::Stranica;
use Mojo::Base -role, -signatures;

use Mojo::File 'path';
use Mojo::ByteStream 'b';
use Mojo::Collection 'c';
use Mojo::Util qw(encode sha1_sum);

around execute => \&_around_execute;

sub _around_execute ($execute, $c) {
  state $cache_pages = $c->config('cache_pages');
  my $is_guest = !$c->is_user_authenticated;
  return 1 if $cache_pages && $is_guest && $c->_render_cached_page();

  my $preview = !$is_guest && $c->param('прегледъ');
  my $stash   = $c->stash;
  my $alias   = $stash->{page_alias};
  my $l       = $c->language;
  my $user    = $c->user;
  my $str     = $c->stranici;
  my $host    = $c->host_only;
  my $page    = $str->find_for_display($alias, $user, $host, $preview);

  # Page was found, but with a new alias, and we are not showing a celina
  # (paragraph/content)
  return $c->_go_to_new_page_url($page, $l)
    if ref $page && $page->{alias} ne $alias && !$stash->{paragraph_alias};

  # Give up - page was not found.
  state $not_found_id = $c->not_found_id;
  $page //= $str->find($not_found_id);

  # Now as we have a page to show, we continue as usual.
  $page->{is_dir} = $page->{permissions} =~ /^d/;

  # User wants a specific template to be used to display this page
  $c->stash($page->{template} ? (template => $page->{template}) : ());

  # Get the content with page_id = $page->{id}.
  my $celini = $c->celini->all_for_display_in_stranica($page, $user, $l, $preview);

  # The translation for this page was not found! Redirecting to the same page with
  # the default language.
  if (!$celini->size) {
    $c->flash(message => "Преводът \"$l\" не бе открит!");
    return $c->redirect_to(
      page_with_lang => {page_alias => $page->{alias}, lang => $stash->{languages}[0]});
  }
  my $celina
    = $celini->first(sub { title => $page->{title}, $_->{box} eq $stash->{boxes}[0] });

  # We were looking for content with 'en' but found en-US
  $l = $c->language($celina->{language})->language;

  state $list_columns = $c->app->defaults('stranici_columns');

  #These are always used so we add them to the stash earlier.
  $c->stash(
    celini       => $celini,
    host         => $host,
    list_columns => $list_columns,
    page         => $page,
    page_alias   => $page->{alias},
    preview      => $preview,
    user         => $user,

    # data_type to template name
    d2t => {
      'note'      => '_beleyazhka',
      'question'  => '_wyprosy',
      'title'     => '_zaglawie',
      'book'      => '_kniga',
      'writing'   => '_pisanie',
      'paragraph' => '_ceyalina',
      'answer'    => '_otgowory'
    },
  );

  state $not_found_code = $c->not_found_code;
  if ($page->{id} == $not_found_id) {
    return $c->render(
      breadcrumb     => c(),
      canonical_path => '',
      celina         => $celina,
      menu           => c(),
      status         => $not_found_code
    );
  }

  # If this is a root page, list in the menu pages under it, otherwise list
  # siblings.
  my $menu = $str->all_for_list(
    $user, $host, $preview, $l,
    {
      columns  => $list_columns,
      pid      => $page->{page_type} eq $str->root_page_type ? $page->{id} : $page->{pid},
      order_by => 'sorting'
    });

  $stash->{canonical_path}
    = $c->url_for(($stash->{paragraph_alias} ? 'para_with_lang' : 'page_with_lang') =>
      {lang => $celina->{language}})->to_abs->path->canonicalize->to_route;

  $c->stash(breadcrumb => $str->breadcrumb($page->{id}, $l), menu => $menu);

  my $ok = $execute->($c, $page, $user, $l, $preview);

  if ($cache_pages && $c->res->is_success) {
    state $cache_control = $c->app->config('cache_control');
    my $hs = $c->res->headers;

    # Cache this page on disk if user is not authenticated.
    if ($is_guest) {
      $hs->cache_control($cache_control);
      $c->_cache_page($l);
    }
    else {
      $hs->cache_control($cache_control =~ s/public/private/r);
    }
  }
  return $ok;
}

sub _go_to_new_page_url ($c, $page, $l) {

  # https://tools.ietf.org/html/rfc7538#section-3
  my $status = $c->req->method =~ /GET|HEAD/i ? 301 : 308;
  $c->res->code($status);
  return $c->redirect_to(page_with_lang => {page_alias => $page->{alias}, lang => $l});
}

my $cached    = 'cached';       # Directory name to save pages to
my $cacheable = qr/\.html$/;    # File exptension for cacheable content

sub _path_to_file ($c, $url_path) {

  # Will be served by Apache or _render_cached_page next time.
  return path($c->app->static->paths->[0], "$cached$url_path") if $ENV{GATEWAY_INTERFACE};

  # Will be served by _render_cached_page.
  return path($c->app->static->paths->[0],
    $cached, sha1_sum(encode('UTF-8' => $url_path)) . '.html');
}

sub _render_cached_page ($c) {
  state $cache_control = $c->app->config('cache_control');
  $c->res->headers->cache_control($cache_control);
  my $url_path
    = $c->url_for(($c->stash->{paragraph_alias} ? 'para_with_lang' : 'page_with_lang') =>
      {lang => $c->language})->to_abs->path->canonicalize->to_route;
  return unless $url_path =~ $cacheable;
  my $file = $c->_path_to_file($url_path);
  return $c->reply->file($file) if -f $file;
  return;
}

# Cache the page on disk which is being rendered for non authenticated users.
# Cached files are deleted when any page or content is changed.
sub _cache_page ($c, $l) {
  my $url_path = $c->stash('canonical_path');
  return unless $url_path =~ $cacheable;
  my $file = $c->_path_to_file($url_path);
  $file->dirname->make_path({mode => oct(755)});
  return $file->spurt($c->res->body =~ s/(<html[^>]+>)/$1<!-- $cached -->/r);
}

# Delete cached pages
# TODO: Execute this in a subprocess as $cache_dir->remove_tree may be slow on
# large directories.
# See http://localhost:3000/perldoc/Mojolicious/Guides/Cookbook#Subprocesses
my $clear_cache = sub ($action, $c) {

  state $app   = $c->app;
  state $droot = $app->config('domove_root');

  my $ok = $action->($c);
  return unless $ok;

  my $cache_dir = path $droot, $c->stash('domain')->{domain}, 'public', $cached;

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
      my $ipad = sprintf '%02d', $i;
      my $src  = path($paths->[0], 'img',
        sha1_sum(encode('UTF-8' => $v->{alias})) . "-$ipad.$ext")->spurt($stream);
      ($img->{src}) = $src =~ m|public(/.+)$|;

      # TODO: resize the image on disc according to 'with' and 'height'
      # attributes if available and keep resolution 96dpi. Save original image
      # as well as resized image. Use resized image in src attribute.
    });
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
  my $user = $c->user;
  my $old  = $m->find_where({'id' => $id, %{$m->writable_by($user)}});
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
        ]);
      $log->error("failed to change mode of $record_type:"
          . $c->dumper($v->error('writable'))
          . __FILE__ . ':'
          . __LINE__);
      return 0;
    }
  }

  # not writable $old
  $old = $m->find_where({'id' => $id, %{$m->readable_by($user)}});
  if ($old->{user_id} != $user->{id}) {
    $v->error(
      writable => [
        'not_owner',
        "user_id: $old->{user_id} != $user->{id}",
        "permissions: $old->{permissions} != $value"
      ]);
    $log->error("failed to change mode of $record_type:"
        . $c->dumper($v->error('writable'))
        . __FILE__ . ':'
        . __LINE__);
    return 0;
  }

  # new permissions
  state $rwx = qr/[r\-][w\-][x\-]/x;
  state $rx  = qr/^[ld\-]($rwx)($rwx)($rwx)$/x;
  my @writable = $value =~ $rx;

  # invalid permissions notation!
  if (!@writable) {
    $v->error(writable => ['invalid_notation', "permissions: '$value'"]);
    $log->error(
      "invalid_notation '$value' for $record_type:" . __FILE__ . ':' . __LINE__);
    return 0;
  }

  # owner can change permissions in place
  if ($writable[0] =~ /^$rwx$/ || $writable[1] =~ /^$rwx$/ || $writable[2] =~ /^$rwx$/) {
    $log->warn("Making the $record_type with id $old->{id}"
        . " not listable for group_id $old->{group_id}: $writable[1]")
      if $writable[1] eq '---';
    $log->warn("Making the $record_type with id $old->{id}"
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
        current_user => $user->{id}}]);

  # unknown error /untested conditions
  $v->error(%error);
  $log->error("unknown_not_writable $record_type:"
      . $c->dumper($v->error('writable'))
      . __FILE__ . ':'
      . __LINE__);
  return 0;
}

# Returns true if this page or content is editable by the current user
sub is_item_editable ($c, $e) {
  my $u = $c->user;
  if ($u->{id} == $e->{user_id}) {
    return 1;
  }
  if ($u->{group_id} == $e->{group_id}) {
    return 1;
  }
  my $groups = $c->stash->{user_groups}
    //= $c->dbx->db->select('user_group', '*', {user_id => $u->{id}})->hashes;

  state $rwx = qr/[r\-][w\-][x\-]/x;

  if ( $groups->first(sub { $_->{group_id} == $e->{group_id} })
    && $e->{permissions} =~ /^[ld\-]${rwx}rw/x)
  {
    $c->debug($e->{id}
        . " is_item_editable? - yes: group_id $e->{group_id} has 'rw' priviledges");
    return 1;
  }

  if ($e->{permissions} =~ /^[ld\-]$rwx${rwx}rw/x) {
    $c->debug($e->{id} . ' is_item_editable? - yes: others with "rw" priviledges');
    return 1;
  }
  $c->debug($e->{id} . ' is_item_editable? - NO. All checks made');
  return 0;
}

# used to generate the options for parent pages.
sub page_id_options ($c, $bread, $row, $u, $d, $l) {
  my $str = $c->stranici;
  my $st  = $c->stash;
  my $root
    = $str->find_where({page_type => $st->{page_types}[0], dom_id => $st->{domain}{id}});

  # Root page of a site should aways have pid=0
  return [['никоя', 0]] if $row->{id} && $row->{id} == $root->{id};
  my $opts
    = {pid => $root->{id}, order_by => ['sorting'], columns => $st->{stranici_columns}};
  my $parents_options = [
    [$root->{alias}, $root->{id}],
    @{
      $str->all_for_edit($u, $d, $l, $opts)->map(sub {
        my $crow = shift;
        _options($c, $crow, $row, 1, $u, $d, $l);
      })}];

# TODO refactor all_for_edit to not require hacks like this (do not pass pid as
# an option, but only in the 'where' suboption)
# Call all_for_edit recursively and show optiongroups for subfolders

  return $parents_options;
}

sub _options ($c, $crow, $row, $indent, $u, $d, $l) {
  return unless $crow->{is_dir};
  return if ($crow->{id} == ($row->{id} // 0));
  state $list_columns = $c->app->defaults('stranici_columns');
  my $opts = {pid => $crow->{id}, order_by => ['sorting'], columns => $list_columns,};

  my $stranici = $c->stranici->all_for_edit($u, $d, $l, $opts);
  my $option   = [
    ('- ' x $indent) . $crow->{alias} => $crow->{id},
    $crow->{id} == $row->{pid} ? (selected => 'selected') : ()];
  if (@$stranici) {
    return $option, @{
      $stranici->map(sub {
        my $crow = shift;
        _options($c, $crow, $row, $indent + 1, $u, $d, $l);
      })};
  }

  return $option;
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
$preview>.  C<$page> is the current page with the title celina in the current
language.  C<$user> is the current user. C<$language> is C<$c->language>.
C<$preview>  is a boolean value - true if the current request is just a preview.
In preview mode C<permissions> and C<published> columns of the records in the
database are not respected.

Beside constructing the page, if there is a cached page or celina with the
requested url path, it is simply slurped and rendered, but only for non
autheticated users.

After the rendering is done by the consuming classes, the constructed response
body is cached and saved on disk. On the next request by a guest user it is
simply rendered, as mentioned above.

Returns the result of C<$c-E<gt>render()>.


=head2 around remove

=head2 around update

In case a celina or a stranica is updated or removed, all cached pages on disk
are deleted. This may feell like small slowdown if you have thousands of cached
pages.


=head2 b64_images_to_files

  $c->b64_images_to_files('foo');

Cleans up a parameter from base64 images and updates it with path to extracted
images.

Expects that the value of the form parameter with name 'foo' is a HTML string.
Scans it for C<img> tags wich contain base64 encoded image in their C<src>
attribute.  Decodes the encoded values and saves them in files in the specific
domain public directory. The files are named after the alias of the record +
count.  Example (Second image in the body of a celina record with alias
'hello'): C<hello-01.png>. Puts the URL path to the newly created file into the
src attribute (e.g. C</img/hello-01.png>). The <src> attributes of the images
are replaced with the paths to the newly created files.

=head2 is_item_editable

Checks the ownership  and permissions of a content item.
Returns true if this page or content is editable by the current user.


    % if ($c->is_item_editable($p)) {
    <li>
        <%= link_to
        url_for(edit_stranici => {id => $p->{id}})
        ->query([language=>$p->{language}]) => (title => 'Промѣна'),
        begin %><i class="fas fa-edit"></i> Промѣна<% end %>
    </li>
    % }

=head2 SEE ALSO

L<Slovo::Controller::Celini>, L<Slovo::Controller::Stranici>

=cut

1;
