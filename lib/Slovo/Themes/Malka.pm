package Slovo::Themes::Malka;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

sub register ($self, $app, $conf) {

  # Prepend class
  unshift @{$app->renderer->classes}, __PACKAGE__;

  # unshift @{$app->static->classes},   __PACKAGE__;

  # Prepend it to the select_box in domove/form.html.ep
  unshift @{$app->config->{domove_templates}}, ['малка' => 'themes/malka'];

  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Themes::Malka - a small theme, using chota.css

=head1 SYNOPSIS

  # in etc/slovo.conf

  plugins => [
    # ...
    # Themes. The precedence is depending on the order here.
    "Themes::Malka"
    # another custom theme
    "Themes::MyTheme"
  ],


=head1 DESCRIPTION

Slovo::Themes::Malka is a core Slovo plugin which is loaded by defauld during
startup. It contains a __DATA__ section with a set of templates for the sites
served by L<Slovo>. It adds itself to the beginning of the
C<@{$renderer-E<gt>classes}> array reference. Also it prepends itself to the
"Themes" select_box in the form for editing domains C<domove/form.html.ep>.
This way the teme can be shosen for use by separate domains, served by Slovo.

Templates from C<__DATA__> section reduce IO operations during startup time as
the application does not have to load them from separate files. This reduces
the overall execution time when the application is run as CGI script.

The templates can be inflated to separate files and customised for your own
deployment using the command L<Mojolicious::Command::Author::inflate>.

=head1 METHODS

=head2 register

Prepends the class to renderer classes and prepends the base path of the
templates from the C<__DATA__> section to C<$conf-E<gt>{domove_templates}>,
which is used in the domains form.
=head1 SEE ALSO

L<Mojolicious::Guides::Tutorial/Stash and templates>,
L<Mojolicious/renderer>,
L<Mojolicious::Renderer>,
L<Mojolicious::Guides::Rendering/Bundling assets with plugins>,
L<Mojolicious::Command::Author::inflate>

=cut

__DATA__

@@ celini/execute.html.ep

<!-- celini/execute -->
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
<%
my $left      = $celini->grep(sub { $_->{box} =~ /left|лѣво/ }) // '';
my $right     = $celini->grep(sub { $_->{box} =~ /right|дѣсно/ }) // '';
my $the_title = shift @$celini;
# Left pane may be shown:
# * (@$left || $page->{is_dir}): if the page has content in the 'left' section or is a directory;
# * 1:always.
layout 'site',
  title => $the_title->{title} . ' ⸙ ' . $celina->{title},
  left  => $left,
  right => $right;
%>
<%=
    include(
      "partials/$d2t->{$celina->{data_type}}", celina => $celina,
      level => 1)
      || include("partials/_data_type" => row => $celina, level => 1)
%>
<!-- end celini/execute -->

@@ layouts/site.html.ep
<!DOCTYPE html>
<html lang="<%= $l %>">
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
  %= include 'partials/_head'
  <body>
    %= include 'partials/_header'
    %#= include 'partials/_left'
    %#TODO:= include 'partials/_right'
    <main class="container">
      % my $messgage = flash('message');
      %= $messgage ? t(div => (class => 'bd-error text-error') => $messgage) : ''
      <%= content %>
    </main>
    %= include 'partials/_footer'    
  </body>
</html> 
@@ partials/_beleyazhka.html.ep
<!-- _note -->
<section class="note">
    %= t 'h' . $level => $celina->{title}
%== format_body($celina)
</section>

@@ partials/_ceyalina.html.ep
<!-- _paragraph -->
<section class="paragraph">
    %= t 'h' . $level => $celina->{title}
%== format_body($celina)
</section>

@@ partials/_data_type.html.ep
<!-- _data_type -->
<!-- from __DATA__ -->
<!-- <%= $domain->{templates} %> -->
<section class="<%= $row->{data_type} %>">
    %= t 'h' . $level => $row->{title}
%== format_body($row)
</section>
<!-- end _data_type -->

@@ partials/_footer.html.ep
<!-- from __DATA__ -->
<!-- <%= $domain->{templates} %> -->
<footer class="is-fixed bg-dark row">
  <nav class="col text-left">
    <%= link_to 'manage' => 'under_management' => (id=>'manage') if $c->is_user_authenticated %>
    Направено съ ♥ и <a target="_blank" href="https://github.com/kberov/Slovo">Слово</a>.
  </nav>
  <nav class="col text-right">
    %= include "partials/_footer_right"
  </nav>
</footer>
@@ partials/_footer_right.html.ep
<%
# This template is here just to be found when the "localhost" domain is served
%><img src="/img/slovo-white.png" style="height: 1rem" />

@@ partials/_head.html.ep
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <link rel="shortcut icon" href="/img/favicon.ico" type="image/x-icon">
    <link rel="canonical" href="/<%=$canonical_path %>">
    
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="generator" content="Slovo <%= $Slovo::VERSION .'/'. $Slovo::CODENAME %>">
    <title><%= title %></title>
    <link rel="stylesheet" href="/css/malka/chota_all.min.css" />
    <link rel="stylesheet" href="/css/malka/site.css" />
    <link rel="stylesheet" href="/css/fonts.css" />
    <script src="/mojo/jquery/jquery.js" ></script>
  </head>
@@ partials/_header.html.ep
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
    <header class="is-fixed bg-dark row">
      <nav class="col-2 nav-left">
        <%=
          link_to sub {
            t(img => (id => 'logo', src => '/img/slovo-white.png'));
          } => url_for(коренъ => {lang => $l})
        %>
        %= (@$breadcrumb ? '⸙':'')
        <%=
        $breadcrumb->map(sub {
          link_to $_->{title},
            page_with_lang => {page_alias => $_->{alias}, lang => $_->{language}} => (
            class => ($page->{id} == $_->{id} ? 'active text-success' : 'text-white'),
            $page->{id} == $_->{id} ? ('aria-current' => 'page') : ());
        })->join('⸙')
          %>
        </nav>
        <nav class="col nav-center">
            % if ($menu->size > 1) {
            <div class="tabs"><%=
            $menu->map(sub {
              return if $page->{id} == $_->{id};
              if ($_->{is_dir}) {
                my $submenu
                  = $c->stranici->all_for_list($user, $domain->{domain}, $preview, $l,
                  {columns => $list_columns, pid => $_->{id}, order_by => 'sorting'});
                if ($submenu->size) {
                  $submenu = $submenu->map(sub {
                    my $s = shift;
                    link_to $s->{title} => page_with_lang =>
                      {page_alias => $s->{alias}, lang => $s->{language}} =>
                      (class => 'text-white');
                  })->join('');

                  #U+25BF WHITE DOWN-POINTING SMALL TRIANGLE
                  return '<div class="dropdown">'
                    . link_to("$_->{title} ▿" => page_with_lang =>
                      {page_alias => $_->{alias}, lang => $_->{language}} =>
                      (class => 'text-white'))
                    . '<div class="menu bg-dark text-left">'
                    . $submenu
                    . '</div></div>';
                }
              }
              return link_to $_->{title}                    => page_with_lang =>
                {page_alias => $_->{alias}, lang => $_->{language}} => (class => 'text-white');
            })->join('')
            %></div>
            % }
      </nav>
      <nav class="col-2 nav-right">
        % if ($c->is_user_authenticated) {
        % my $name = $user->{first_name} . ' ' . $user->{last_name};
            %= link_to 'Изходъ '.$name => 'sign_out'
        % } else {
            %= link_to 'Входъ' => 'sign_in'
        % }
        %= include 'partials/_lang_menu'
      </nav>
    </header>

@@ partials/_kniga.html.ep
<!-- _book -->
<!-- from __DATA__ -->
<!-- <%= $domain->{templates} %> -->
<section class="<%= $row->{data_type} %>">
    %= t 'h' . $level => $celina->{title}
%== format_body($celina)
</section>

@@ partials/_lang_menu.html.ep
<!-- from __DATA__ -->
<!-- <%= $domain->{templates} %> -->
<%
# List of languages for the current page content.
my $langs = stranici->languages($page, $user, $preview)
  ->sort(sub { ($a->{language} eq $l) <=> ($b->{language} eq $l) });
return if @$langs == 1;

# get the current language
my $current = pop @$langs;
%>
 <div class="dropdown" style="margin-left:1rem;">
    %= $current->{language}
  <div class="menu bg-dark" style="right: 0">
    <%=
    $langs->sort(sub { $a->{language} cmp $b->{language} })->map(sub {
        link_to $_->{language} => 'page_with_lang' =>
          {page_alias => $page->{alias}, lang => $_->{language}} => (title => $_->{title});
    })->join($/);
    %>
  </div>
</div>

@@ partials/_left.html.ep
<!-- todo  -->
@@ partials/_left_menu_stranici.html.ep
<%
#Code in this template is deprecated. now we have $menu collection prepared in Slovo::Role::arount_action()
Mojo::Util::deprecated("Please review 'partials/_left_menu_stranici.html.ep' "
    . " according to what is provided by the controller") my $opts
  = {pid => $page->{pid}, columns => $list_columns};
my $list
  = $c->stranici->all_for_list($user, $domain->{domain}, $preview, language, $opts);
%>
  <ul>
<%==
$list->map(sub {
  my $expander_link = '';
  my $link          = link_to $_->{title} => page_with_lang =>
    {page_alias => $_->{alias}, lang => $_->{language}};
  if ($_->{is_dir}) {
    $expander_link = link_to
      '☰' =>
      url_for('/api/stranici')->query(pid => $_->{id}, 'lang' => $_->{language}),
      (class => 'folder-expander mui--pull-right');
    return t li => sub {
      t strong => sub { $link . ' ' . $expander_link }
    };
  }
  return t li => sub {
    t div => sub { $link . ' ' . $expander_link }
  };
})->join($/);
%>
  </ul>
@@ partials/_otgowory.html.ep
<!-- _answer -->
<section class="answer">
    %= t 'h' . $level => $celina->{title}
%== format_body($celina)
</section>
@@ partials/_pisanie.html.ep
<!-- _writing -->
<section class="writing">
    %= t 'h' . $level => $celina->{title}
%==format_body($celina)
</section>
<!-- end _writing -->
@@ partials/_pisanie_otkysy.html.ep
<%
my $col_num = $num == 1 ? '-0' : '-6';
$col_num = '-0' if ($num == $last) && !($last % 2);

my $link    = link_to $celina->{title} => para_with_lang => {
    page_alias      => $p->{alias},
    paragraph_alias => $celina->{alias},
    lang            => $celina->{language}
} => (title => $celina->{title});
my $html = html_substr($celina->{teaser} // $celina->{body},
    'p,blockquote', $col_num eq '-0' ? 220 * 2 : 220);
%>
<!-- <%= $celina->{data_type} ." $num" %> exerpt -->
    <div class="card col<%= $col_num %> <%= $celina->{data_type} %>">
        <header><h4><%= $link %></h4></header>
        %== $html
    </div>

@@ partials/_right.html.ep
    % if ( @$right ) {
    <!-- right -->
    %= t aside => (class=>"right") => begin
        <%==
        $right->map(sub {
          ($_->{title} ? t h2 => $_->{title} : '') . $/ . ($_->{body} ? $_->{body} : '');
        })->join($/)
        %>
    % end
    % }
    <!-- end right -->

@@ partials/_wyprosy.html.ep
<!-- _question -->
<section class="question">
    %= t 'h' . $level => $celina->{title} =~ s/<[^>]+>?//gr;
%==format_body($celina)
</section>
@@ partials/_zaglawie.html.ep
<!-- partials/_zaglawie -->
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
<%
# The content element can be displayed in two contexts.
# 1. Страница a.k.a. List context:
# if ($controller eq 'stranici' && $title->{permissions} =~ /^d/)
# This is when it is displayed as part (title) of the page.
# This context is when the url to the page only is accessed
# (e.g. http://local.слово.бг:3000/вести.html). In this context the
# content element looks if it is a directory and lists its content, if yes.
# 2. Цѣлина a.k.a Scalar context:
# This is when it is displayed as the main content of the page. In this case it
# simply shows it's body or does something intended for this context.
my $list_context = ($controller eq 'stranici' && $celina->{permissions} =~ /^d/);
%>
    %= t 'h' . $level => $celina->{title};
% if ($list_context) { #List
 %== format_body($celina)
   <section class="row">
    <%
    my $limit  = 9;
    my $celini = celini->all_for_display_in_stranica(
      $page, $user, $l, $preview,
      {
        where => {

          # avoid recursion
          'celini.pid'       => {'='  => $celina->{id}, '!=' => {-ident => 'celini.id'}},
          'celini.data_type' => {'!=' => 'title'},
          'celini.box'       => $boxes->[0]
        },
        limit => $limit
      }
    );
    my $count = 1;
    my $size  = $celini->size;
    %>
    <%==
    $celini->map(sub {
      my $row = shift;
      return include("partials/_pisanie_otkysy", num => $count++, last =>$size, celina => $row, p => $page);
    })->join($/);
    %>
  </section>
% } else {
    %== format_body($celina)
% }
<!-- end partials/_zaglawie -->

@@ stranici/templates/dom.html.ep
<!-- stranici/templates/dom -->
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
<%
# Template for the home page of a domain. It assumes that all the pages under
# it are sections(tabs) in the site. Therefore it displays each page as a box
# with its title and a short explanation text taken from the title celina of the
# page. 
my $main  = $celini->grep(sub { $_->{box} eq $boxes->[0] });
my $left  = $celini->grep(sub { $_->{box} eq $boxes->[1] });
my $right = $celini->grep(sub { $_->{box} eq $boxes->[2] });
my $the_title = shift @$main;
# Left pane may be shown:
# * (@$left || $page->{is_dir}): if the page has content in the 'left' section or is a directory;
# * 1:always.
layout 'site',
  title      => $the_title->{title},
  left       => $left,
  right      => $right,

# Get the body for each page under the home page.
$menu->each(
    sub {
        $_->{body} = celini->one(
            {columns => ['body'], where => {title => $_->{title}, box => $boxes->[0]}})
          ->{body};
    }
);
%>
<section id="page-<%= $page->{id} %>">
<h1><%= $the_title->{title} %></h1>
    <%== $the_title->{body} %>
</section>
<section class="row">
<% 
for my $p (@$menu) {
my $link
  = link_to $p->{title} => 'page_with_lang' => {page_alias => $p->{alias}, lang => $l} =>
  (title => $p->{title});
%>
    <div class="card col-6 writing" id="page-<%= $p->{id} %>">
        <header><h4><%= $link %></h4></header>
        %== html_substr($p->{body}, 'p, blockquote', 220);
    </div>
<% } %>
</section>
<!-- end stranici/templates/dom -->
@@ stranici/execute.html.ep
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
<!-- stranici/execute -->
<%
# When a page is executed it shows it's title in the current language ( taken
# from the content with data_type 'title') and lists all other content rows which
# have pid==$the_title->{id}.
my $main  = $celini->grep(sub { $_->{box} eq $boxes->[0] });
my $left  = $celini->grep(sub { $_->{box} eq $boxes->[1] });
my $right = $celini->grep(sub { $_->{box} eq $boxes->[2] });
my $the_title = shift @$main;

layout 'site',
  title      => $the_title->{title},
  left       => $left,
  right      => $right;
%>
%= include 'partials/_zaglawie' => (celina => $the_title, level => 1);
<%==
$main->map(sub {
  my $row = shift;
  return include("partials/$d2t->{$row->{data_type}}", celina => $row,
    level => 1)
    || include("partials/_data_type" => row => $row, level => 1);
})->join($/);
%>
<!-- end stranici/execute -->
