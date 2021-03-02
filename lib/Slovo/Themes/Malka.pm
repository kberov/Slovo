package Slovo::Themes::Malka;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

sub register ($self, $app, $conf) {

  # Prepend class
  unshift @{$app->renderer->classes}, __PACKAGE__;

  unshift @{$app->static->classes}, __PACKAGE__;

  # Apppend it to the select_box in domove/_form.html.ep
  $conf //= {};
  $conf->{templates} //= ['themes/malka' => 'themes/malka'];
  push @{$app->config->{domove_templates} //= []}, $conf->{templates};

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
    {"Themes::MyTheme"=>{templates=>['themes/my_theme' => 'themes/my_theme']}}
  ],


=head1 DESCRIPTION

Slovo::Themes::Malka is a core plugin which is loaded by defauld during
startup. It contains a __DATA__ section with a set of templates and static
files. It adds itself to the beginning of the
C<@{$renderer-E<gt>classes}>. Also it appends its suggested relative
path C<themes/malka> to the "Themes" select_box in the form for editing domains
C<domove/form.html.ep>. This way the theme can be shosen for use by separate
domains, served by one Slovo instance.

Note that the theme must be inflated first to the respective C<domove> folder
for the selection to work. See L<Slovo::Command::Author::inflate>.

The theme holds templates and static files in its C<__DATA__> section.
Templates from C<__DATA__> section reduce IO operations during startup time as
the application does not have to load them from separate files. This reduces
the overall execution time when the application is run as a CGI script. This
works well for one-site deployments or several sites, using the same theme.

The templates and static files can be inflated to separate files and customised
for your own deployment using the command
L<Slovo::Command::Author::inflate>. Here is an example with an
internationalized domain name (IDN) - слово.бг (xn--b1arjbl.xn--90ae).

  bin/slovo inflate --class Slovo::Themes::Malka -t \
    --path domove/xn--b1arjbl.xn--90ae/templates/themes/malka
  bin/slovo inflate --class Slovo::Themes::Malka -p \
    --path domove/xn--b1arjbl.xn--90ae

=head1 METHODS

The usual method is implemented.

=head2 register

Prepends the class to renderer and static classes and prepends the base path of the
templates from the C<__DATA__> section to C<$conf-E<gt>{domove_templates}>,
which is used in the domains form.

=head1 EMBEDDED FILES

Currently this theme embeds the following files. They will be inflated when
using the given example at the end of the  L<DESCRIPTION>.

    @@ celini/execute.html.ep
    @@ layouts/site.html.ep
    @@ partials/_beleyazhka.html.ep
    @@ partials/_ceyalina.html.ep
    @@ partials/_data_type.html.ep
    @@ partials/_footer.html.ep
    @@ partials/_footer_right.html.ep
    @@ partials/_head.html.ep
    @@ partials/_header.html.ep
    @@ partials/_kniga.html.ep
    @@ partials/_lang_menu.html.ep
    @@ partials/_left.html.ep
    @@ partials/_left_menu_stranici.html.ep
    @@ partials/_otgowory.html.ep
    @@ partials/_pisanie.html.ep
    @@ partials/_pisanie_otkysy.html.ep
    @@ partials/_right.html.ep
    @@ partials/_wyprosy.html.ep
    @@ partials/_zaglawie.html.ep
    @@ stranici/templates/dom.html.ep
    @@ stranici/execute.html.ep
    @@ css/malka/chota_all_min.css
    @@ css/malka/site.css

=head1 SEE ALSO

L<Mojolicious::Guides::Tutorial/Stash and templates>,
L<Mojolicious/renderer>,
L<Mojolicious::Renderer>,
L<Mojolicious::Guides::Rendering/Bundling assets with plugins>,
L<Slovo::Command::Author::inflate>

=cut

__DATA__

@@ celini/execute.html.ep

<!-- celini/execute -->
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
<%
my $left       = $celini->grep(sub { $_->{box} =~ /left|лѣво/ })   // '';
my $right      = $celini->grep(sub { $_->{box} =~ /right|дѣсно/ }) // '';
my $page_title = shift @$celini;
my $author     = users->find($celina->{user_id});
my $description
  = $celina->{description} || substr(Mojo::DOM->new($celina->{body})->all_text, 0, 250);
my $keywords = $celina->{keywords}
  || Mojo::Collection->new(split(/\W+/, $description))->uniq->grep(qr/\w{4,}/)->join(',');
# Left pane may be shown:
# * (@$left || $page->{is_dir}): if the page has content in the 'left' section or is a directory;
# * 1:always.
layout 'site',
  author      => $author->{first_name} . ' ' . $author->{last_name},
  description => $description,
  keywords    => $keywords,
  left        => $left,
  right       => $right,
  title       => $page_title->{title} . ' ⸙ ' . $celina->{title},
  ;
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
    <div class="pull-right text-right"><%= include "partials/_footer_right" %></div>
    <%= link_to 'manage' => 'under_management' => (id=>'manage') if $c->is_user_authenticated %>
    Направено съ ♥ и <a target="_blank" href="https://github.com/kberov/Slovo">Слово</a>.
  </nav>
</footer>
@@ partials/_footer_right.html.ep
<%
# This template i here just to be found when the "localhost" domain is served
%><img src="/img/slovo-white.png" style="height: 1rem" />

@@ partials/_head.html.ep
<!-- from __DATA__ -->
<!-- <%=$domain->{templates} %> -->
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <link rel="shortcut icon" href="/img/favicon.ico" type="image/x-icon">
    <link rel="canonical" href="/<%=$canonical_path %>">
    
    <meta name="author" content="<%= $author %>">
    <meta name="description" content="<%= $description %>">
    <meta name="generator" content="Slovo <%= $Slovo::VERSION .'/'. $Slovo::CODENAME %>">
    <meta name="keywords" content="<%= $keywords %>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= title %></title>
    <link rel="stylesheet" href="/css/malka/chota_all_min.css" />
    <link rel="stylesheet" href="/css/fonts.css" />
    <link rel="stylesheet" href="/css/malka/site.css" />
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
my $page_title = shift @$main;
my $author      = users->find($page_title->{user_id});
my $description = $page_title->{description}
  || substr(Mojo::DOM->new($page_title->{body})->all_text, 0, 250);
my $keywords
  = $page_title->{keywords}
  || Mojo::Collection->new(split(/\W+/, $description))->uniq->grep(qr/\w{4,}/)
  ->join(',');
# Left pane may be shown:
# * (@$left || $page->{is_dir}): if the page has content in the 'left' section or is a directory;
# * 1:always.
layout 'site',
  author      => $author->{first_name} . ' ' . $author->{last_name},
  description => $description,
  keywords    => $keywords,
  left        => $left,
  right       => $right,
  title       => $page_title->{title},
  ;

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
<h1><%= $page_title->{title} %></h1>
    <%== $page_title->{body} %>
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
# have pid==$page_title->{id}.
my $main       = $celini->grep(sub { $_->{box} eq $boxes->[0] });
my $left       = $celini->grep(sub { $_->{box} eq $boxes->[1] });
my $right      = $celini->grep(sub { $_->{box} eq $boxes->[2] });
my $page_title  = shift @$main;
my $author      = users->find($page_title->{user_id});
my $description = $page_title->{description}
  || substr(Mojo::DOM->new($page_title->{body})->all_text, 0, 250);
my $keywords
  = $page_title->{keywords}
  || Mojo::Collection->new(split(/\W+/, $description))->uniq->grep(qr/\w{4,}/)
  ->join(',');

layout 'site',
  author      => $author->{first_name} . ' ' . $author->{last_name},
  description => $description,
  keywords    => $keywords,
  left        => $left,
  right       => $right,
  title       => $page_title->{title},
  ;
%>
%= include 'partials/_zaglawie' => (celina => $page_title, level => 1);
<%==
$main->map(sub {
  my $row = shift;
  return include("partials/$d2t->{$row->{data_type}}", celina => $row,
    level => 1)
    || include("partials/_data_type" => row => $row, level => 1);
})->join($/);
%>
<!-- end stranici/execute -->

@@ css/malka/chota_all_min.css
/*! normalize.css v8.0.1 | MIT License | github.com/necolas/normalize.css */
html{line-height:1.15;-webkit-text-size-adjust:100%}body{margin:0}main{display:block}h1{font-size:2em;margin:0.67em 0}hr{box-sizing:content-box;height:0;overflow:visible}pre{font-family:monospace,monospace;font-size:1em}a{background-color:transparent}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}b,strong{font-weight:bolder}code,kbd,samp{font-family:monospace,monospace;font-size:1em}small{font-size:80%}sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}sub{bottom:-0.25em}sup{top:-0.5em}img{border-style:none}button,input,optgroup,select,textarea{font-family:inherit;font-size:100%;line-height:1.15;margin:0}button,input{overflow:visible}button,select{text-transform:none}button,[type="button"],[type="reset"],[type="submit"]{-webkit-appearance:button}button::-moz-focus-inner,[type="button"]::-moz-focus-inner,[type="reset"]::-moz-focus-inner,[type="submit"]::-moz-focus-inner{border-style:none;padding:0}button:-moz-focusring,[type="button"]:-moz-focusring,[type="reset"]:-moz-focusring,[type="submit"]:-moz-focusring{outline:1px dotted ButtonText}fieldset{padding:0.35em 0.75em 0.625em}legend{box-sizing:border-box;color:inherit;display:table;max-width:100%;padding:0;white-space:normal}progress{vertical-align:baseline}textarea{overflow:auto}[type="checkbox"],[type="radio"]{box-sizing:border-box;padding:0}[type="number"]::-webkit-inner-spin-button,[type="number"]::-webkit-outer-spin-button{height:auto}[type="search"]{-webkit-appearance:textfield;outline-offset:-2px}[type="search"]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}details{display:block}summary{display:list-item}template{display:none}[hidden]{display:none}
/*! chota.css v0.8.0 | MIT License | github.com/jenil/chota */
:root{--bg-color:#ffffff;--bg-secondary-color:#f3f3f6;--color-primary:#14854F;--color-lightGrey:#d2d6dd;--color-grey:#747681;--color-darkGrey:#3f4144;--color-error:#d43939;--color-success:#28bd14;--grid-maxWidth:80rem;--grid-gutter:2rem;--font-size:1.6rem;--font-color:#333333;--font-family-sans:FreeSans,sans-serif;--font-family-mono:FreeMono,monospace}html{box-sizing:border-box;font-size:62.5%;line-height:1.15;-ms-text-size-adjust:100%;-webkit-text-size-adjust:100%}*,*:before,*:after{box-sizing:inherit}*{scrollbar-width:thin;scrollbar-color:var(--color-lightGrey) var(--bg-primary)}*::-webkit-scrollbar{width:8px}*::-webkit-scrollbar-track{background:var(--bg-primary)}*::-webkit-scrollbar-thumb{background:var(--color-lightGrey)}body{background-color:var(--bg-color);line-height:1.6;font-size:var(--font-size);color:var(--font-color);font-family:"Segoe UI","Helvetica Neue",sans-serif;font-family:var(--font-family-sans);margin:0;padding:0}h1,h2,h3,h4,h5,h6{font-weight:500;margin:0.35em 0 0.7em 0}h1{font-size:2em}h2{font-size:1.75em}h3{font-size:1.5em}h4{font-size:1.25em}h5{font-size:1em}h6{font-size:0.85em}a{color:var(--color-primary);text-decoration:none}a:hover:not(.button){opacity:0.75}button{font-family:inherit}p{margin-top:0}blockquote{background-color:var(--bg-secondary-color);padding:1.5rem 2rem;border-left:3px solid var(--color-lightGrey)}dl dt{font-weight:bold}hr{border:none;background-color:var(--color-lightGrey);height:1px;margin:1rem 0}table{width:100%;border:none;border-collapse:collapse;border-spacing:0;text-align:left}table.striped tr:nth-of-type(2n){background-color:var(--bg-secondary-color)}td,th{vertical-align:middle;padding:1.2rem 0.4rem}thead{border-bottom:2px solid var(--color-lightGrey)}tfoot{border-top:2px solid var(--color-lightGrey)}code,kbd,pre,samp,tt{font-family:var(--font-family-mono)}code,kbd{padding:0 0.4rem;font-size:90%;white-space:pre-wrap;border-radius:var(--border-radius);padding:0.2em 0.4em;background-color:var(--bg-secondary-color);color:var(--color-error)}pre{background-color:var(--bg-secondary-color);font-size:1em;padding:1rem;overflow-x:auto}pre code{background:none;padding:0}abbr[title]{border-bottom:none;text-decoration:underline;text-decoration:underline dotted}img{max-width:100%}fieldset{border:1px solid var(--color-lightGrey)}iframe{border:0}.container{max-width:var(--grid-maxWidth);margin:0 auto;width:96%;padding:0 calc(var(--grid-gutter) / 2)}.row{display:flex;flex-flow:row wrap;justify-content:flex-start;margin-left:calc(var(--grid-gutter) / -2);margin-right:calc(var(--grid-gutter) / -2)}.row.reverse{flex-direction:row-reverse}.col{flex:1}.col,[class*=" col-"],[class^='col-']{margin:0 calc(var(--grid-gutter) / 2) calc(var(--grid-gutter) / 2)}.col-1{flex:0 0 calc((100% / (12/1)) - var(--grid-gutter));max-width:calc((100% / (12/1)) - var(--grid-gutter))}.col-2{flex:0 0 calc((100% / (12/2)) - var(--grid-gutter));max-width:calc((100% / (12/2)) - var(--grid-gutter))}.col-3{flex:0 0 calc((100% / (12/3)) - var(--grid-gutter));max-width:calc((100% / (12/3)) - var(--grid-gutter))}.col-4{flex:0 0 calc((100% / (12/4)) - var(--grid-gutter));max-width:calc((100% / (12/4)) - var(--grid-gutter))}.col-5{flex:0 0 calc((100% / (12/5)) - var(--grid-gutter));max-width:calc((100% / (12/5)) - var(--grid-gutter))}.col-6{flex:0 0 calc((100% / (12/6)) - var(--grid-gutter));max-width:calc((100% / (12/6)) - var(--grid-gutter))}.col-7{flex:0 0 calc((100% / (12/7)) - var(--grid-gutter));max-width:calc((100% / (12/7)) - var(--grid-gutter))}.col-8{flex:0 0 calc((100% / (12/8)) - var(--grid-gutter));max-width:calc((100% / (12/8)) - var(--grid-gutter))}.col-9{flex:0 0 calc((100% / (12/9)) - var(--grid-gutter));max-width:calc((100% / (12/9)) - var(--grid-gutter))}.col-10{flex:0 0 calc((100% / (12/10)) - var(--grid-gutter));max-width:calc((100% / (12/10)) - var(--grid-gutter))}.col-11{flex:0 0 calc((100% / (12/11)) - var(--grid-gutter));max-width:calc((100% / (12/11)) - var(--grid-gutter))}.col-12{flex:0 0 calc((100% / (12/12)) - var(--grid-gutter));max-width:calc((100% / (12/12)) - var(--grid-gutter))}@media screen and (max-width:599px){.container{width:100%}.col,[class*="col-"],[class^='col-']{flex:0 1 100%;max-width:100%}}@media screen and (min-width:900px){.col-1-md{flex:0 0 calc((100% / (12/1)) - var(--grid-gutter));max-width:calc((100% / (12/1)) - var(--grid-gutter))}.col-2-md{flex:0 0 calc((100% / (12/2)) - var(--grid-gutter));max-width:calc((100% / (12/2)) - var(--grid-gutter))}.col-3-md{flex:0 0 calc((100% / (12/3)) - var(--grid-gutter));max-width:calc((100% / (12/3)) - var(--grid-gutter))}.col-4-md{flex:0 0 calc((100% / (12/4)) - var(--grid-gutter));max-width:calc((100% / (12/4)) - var(--grid-gutter))}.col-5-md{flex:0 0 calc((100% / (12/5)) - var(--grid-gutter));max-width:calc((100% / (12/5)) - var(--grid-gutter))}.col-6-md{flex:0 0 calc((100% / (12/6)) - var(--grid-gutter));max-width:calc((100% / (12/6)) - var(--grid-gutter))}.col-7-md{flex:0 0 calc((100% / (12/7)) - var(--grid-gutter));max-width:calc((100% / (12/7)) - var(--grid-gutter))}.col-8-md{flex:0 0 calc((100% / (12/8)) - var(--grid-gutter));max-width:calc((100% / (12/8)) - var(--grid-gutter))}.col-9-md{flex:0 0 calc((100% / (12/9)) - var(--grid-gutter));max-width:calc((100% / (12/9)) - var(--grid-gutter))}.col-10-md{flex:0 0 calc((100% / (12/10)) - var(--grid-gutter));max-width:calc((100% / (12/10)) - var(--grid-gutter))}.col-11-md{flex:0 0 calc((100% / (12/11)) - var(--grid-gutter));max-width:calc((100% / (12/11)) - var(--grid-gutter))}.col-12-md{flex:0 0 calc((100% / (12/12)) - var(--grid-gutter));max-width:calc((100% / (12/12)) - var(--grid-gutter))}}@media screen and (min-width:1200px){.col-1-lg{flex:0 0 calc((100% / (12/1)) - var(--grid-gutter));max-width:calc((100% / (12/1)) - var(--grid-gutter))}.col-2-lg{flex:0 0 calc((100% / (12/2)) - var(--grid-gutter));max-width:calc((100% / (12/2)) - var(--grid-gutter))}.col-3-lg{flex:0 0 calc((100% / (12/3)) - var(--grid-gutter));max-width:calc((100% / (12/3)) - var(--grid-gutter))}.col-4-lg{flex:0 0 calc((100% / (12/4)) - var(--grid-gutter));max-width:calc((100% / (12/4)) - var(--grid-gutter))}.col-5-lg{flex:0 0 calc((100% / (12/5)) - var(--grid-gutter));max-width:calc((100% / (12/5)) - var(--grid-gutter))}.col-6-lg{flex:0 0 calc((100% / (12/6)) - var(--grid-gutter));max-width:calc((100% / (12/6)) - var(--grid-gutter))}.col-7-lg{flex:0 0 calc((100% / (12/7)) - var(--grid-gutter));max-width:calc((100% / (12/7)) - var(--grid-gutter))}.col-8-lg{flex:0 0 calc((100% / (12/8)) - var(--grid-gutter));max-width:calc((100% / (12/8)) - var(--grid-gutter))}.col-9-lg{flex:0 0 calc((100% / (12/9)) - var(--grid-gutter));max-width:calc((100% / (12/9)) - var(--grid-gutter))}.col-10-lg{flex:0 0 calc((100% / (12/10)) - var(--grid-gutter));max-width:calc((100% / (12/10)) - var(--grid-gutter))}.col-11-lg{flex:0 0 calc((100% / (12/11)) - var(--grid-gutter));max-width:calc((100% / (12/11)) - var(--grid-gutter))}.col-12-lg{flex:0 0 calc((100% / (12/12)) - var(--grid-gutter));max-width:calc((100% / (12/12)) - var(--grid-gutter))}}fieldset{padding:0.5rem 2rem}legend{text-transform:uppercase;font-size:0.8em;letter-spacing:0.1rem}input:not([type="checkbox"]):not([type="radio"]):not([type="submit"]):not([type="color"]):not([type="button"]):not([type="reset"]),select,textarea,textarea[type="text"]{font-family:inherit;padding:0.8rem 1rem;border-radius:var(--border-radius);border:1px solid var(--color-lightGrey);font-size:1em;transition:all 0.2s ease;display:block;width:100%}input:not([type="checkbox"]):not([type="radio"]):not([type="submit"]):not([type="color"]):not([type="button"]):not([type="reset"]):not(:disabled):hover,select:hover,textarea:hover,textarea[type="text"]:hover{border-color:var(--color-grey)}input:not([type="checkbox"]):not([type="radio"]):not([type="submit"]):not([type="color"]):not([type="button"]):not([type="reset"]):focus,select:focus,textarea:focus,textarea[type="text"]:focus{outline:none;border-color:var(--color-primary);box-shadow:0 0 1px var(--color-primary)}input.error:not([type="checkbox"]):not([type="radio"]):not([type="submit"]):not([type="color"]):not([type="button"]):not([type="reset"]),textarea.error{border-color:var(--color-error)}input.success:not([type="checkbox"]):not([type="radio"]):not([type="submit"]):not([type="color"]):not([type="button"]):not([type="reset"]),textarea.success{border-color:var(--color-success)}select{-webkit-appearance:none;background:#f3f3f6 no-repeat 100%;background-size:1ex;background-origin:content-box;background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='60' height='40' fill='%23555'><polygon points='0,0 60,0 30,40'/></svg>")}[type="checkbox"],[type="radio"]{width:1.6rem;height:1.6rem}.button,[type="button"],[type="reset"],[type="submit"],button{padding:1rem 2.5rem;color:var(--color-darkGrey);background:var(--color-lightGrey);border-radius:var(--border-radius);border:1px solid transparent;font-size:var(--font-size);line-height:1;text-align:center;transition:opacity 0.2s ease;text-decoration:none;transform:scale(1);display:inline-block;cursor:pointer}.grouped{display:flex}.grouped>*:not(:last-child){margin-right:16px}.grouped.gapless>*{margin:0 0 0 -1px !important;border-radius:0 !important}.grouped.gapless>*:first-child{margin:0 !important;border-radius:var(--border-radius) 0 0 var(--border-radius) !important}.grouped.gapless>*:last-child{border-radius:0 var(--border-radius) var(--border-radius) 0 !important}.button + .button{margin-left:1rem}.button:hover,[type="button"]:hover,[type="reset"]:hover,[type="submit"]:hover,button:hover{opacity:0.8}.button:active,[type="button"]:active,[type="reset"]:active,[type="submit"]:active,button:active{transform:scale(0.98)}input:disabled,button:disabled,input:disabled:hover,button:disabled:hover{opacity:0.4;cursor:not-allowed}.button.primary,.button.secondary,.button.dark,.button.error,.button.success,[type="submit"]{color:#fff;z-index:1;background-color:#000;background-color:var(--color-primary)}.button.secondary{background-color:var(--color-grey)}.button.dark{background-color:var(--color-darkGrey)}.button.error{background-color:var(--color-error)}.button.success{background-color:var(--color-success)}.button.outline{background-color:transparent;border-color:var(--color-lightGrey)}.button.outline.primary{border-color:var(--color-primary);color:var(--color-primary)}.button.outline.secondary{border-color:var(--color-grey);color:var(--color-grey)}.button.outline.dark{border-color:var(--color-darkGrey);color:var(--color-darkGrey)}.button.clear{background-color:transparent;border-color:transparent;color:var(--color-primary)}.button.icon{display:inline-flex;align-items:center}.button.icon>img{margin-left:2px}.button.icon-only{padding:1rem}::placeholder{color:#bdbfc4}.nav{display:flex;min-height:5rem;align-items:stretch}.nav img{max-height:3rem}.nav>.container{display:flex}.nav-center,.nav-left,.nav-right{display:flex;flex:1}.nav-left{justify-content:flex-start}.nav-right{justify-content:flex-end}.nav-center{justify-content:center}@media screen and (max-width:480px){.nav,.nav>.container{flex-direction:column}.nav-center,.nav-left,.nav-right{flex-wrap:wrap;justify-content:center}}.nav a,.nav .brand{text-decoration:none;display:flex;align-items:center;padding:1rem 2rem;color:var(--color-darkGrey)}.nav [aria-current="page"]:not(.button),.nav .active:not(.button){color:#000;color:var(--color-primary)}.nav .brand{font-size:1.75em;padding-top:0;padding-bottom:0}.nav .brand img{padding-right:1rem}.nav .button{margin:auto 1rem}.card{padding:1rem 2rem;border-radius:var(--border-radius);background:var(--bg-color);box-shadow:0 1px 3px var(--color-grey)}.card p:last-child{margin:0}.card header>*{margin-top:0;margin-bottom:1rem}.tabs{display:flex}.tabs a{text-decoration:none}.tabs>.dropdown>summary,.tabs>a{padding:1rem 2rem;flex:0 1 auto;color:var(--color-darkGrey);border-bottom:2px solid var(--color-lightGrey);text-align:center}.tabs>a[aria-current="page"],.tabs>a.active,.tabs>a:hover{opacity:1;border-bottom:2px solid var(--color-darkGrey)}.tabs>a[aria-current="page"],.tabs>a.active{border-color:var(--color-primary)}.tabs.is-full a{flex:1 1 auto}.tag{display:inline-block;border:1px solid var(--color-lightGrey);text-transform:uppercase;color:var(--color-grey);padding:0.5rem;line-height:1;letter-spacing:0.5px}.tag.is-small{padding:0.4rem;font-size:0.75em}.tag.is-large{padding:0.7rem;font-size:1.125em}.tag+.tag{margin-left:1rem}details.dropdown{position:relative;display:inline-block}details.dropdown>:last-child{position:absolute;left:0;white-space:nowrap}.bg-primary{background-color:var(--color-primary) !important}.bg-light{background-color:var(--color-lightGrey) !important}.bg-dark{background-color:var(--color-darkGrey) !important}.bg-grey{background-color:var(--color-grey) !important}.bg-error{background-color:var(--color-error) !important}.bg-success{background-color:var(--color-success) !important}.bd-primary{border:1px solid var(--color-primary) !important}.bd-light{border:1px solid var(--color-lightGrey) !important}.bd-dark{border:1px solid var(--color-darkGrey) !important}.bd-grey{border:1px solid var(--color-grey) !important}.bd-error{border:1px solid var(--color-error) !important}.bd-success{border:1px solid var(--color-success) !important}.text-primary{color:var(--color-primary) !important}.text-light{color:var(--color-lightGrey) !important}.text-dark{color:var(--color-darkGrey) !important}.text-grey{color:var(--color-grey) !important}.text-error{color:var(--color-error) !important}.text-success{color:var(--color-success) !important}.text-white{color:#fff !important}.pull-right{float:right !important}.pull-left{float:left !important}.text-center{text-align:center}.text-left{text-align:left}.text-right{text-align:right}.text-justify{text-align:justify}.text-uppercase{text-transform:uppercase}.text-lowercase{text-transform:lowercase}.text-capitalize{text-transform:capitalize}.is-full-screen{width:100%;min-height:100vh}.is-full-width{width:100% !important}.is-vertical-align{display:flex;align-items:center}.is-horizontal-align{display:flex;justify-content:center}.is-center{display:flex;align-items:center;justify-content:center}.is-right{display:flex;align-items:center;justify-content:flex-end}.is-left{display:flex;align-items:center;justify-content:flex-start}.is-fixed{position:fixed;width:100%}.is-paddingless{padding:0 !important}.is-marginless{margin:0 !important}.is-pointer{cursor:pointer !important}.is-rounded{border-radius:100%}.clearfix{content:"";display:table;clear:both}.is-hidden{display:none !important}@media screen and (max-width:599px){.hide-xs{display:none !important}}@media screen and (min-width:600px) and (max-width:899px){.hide-sm{display:none !important}}@media screen and (min-width:900px) and (max-width:1199px){.hide-md{display:none !important}}@media screen and (min-width:1200px){.hide-lg{display:none !important}}@media print{.hide-pr{display:none !important}}

@@ css/malka/site.css

:root {
  --border-radius:  10px;
  --color-success: #23FF04
}
* {
  scrollbar-width: auto;
  scrollbar-color: var(--color-lightGrey) var(--color-darkGrey);
}
*::-webkit-scrollbar {
  width:1rem
}
body>header, body>footer {
  --box-shadow: 0 0.1em 0.5em var(--color-darkGrey);
  z-index: 1;
  margin: 0 !important;
  /* offset-x | offset-y | blur-radius | color */
  box-shadow: var(--box-shadow);
}
body>header {
  top: 0
}
body>footer {
  bottom: 0
}
#logo {
  display: inline;
  width: 1.5rem;
  vertical-align: middle;
}
body>header, body>footer, body>header a, body>footer a {
  color: white;
}
nav .tabs a {
  padding: 0rem 1rem;
  white-space: nowrap;
}
nav .tabs a.active {
  color: var(--color-success) !important;
}
.dropdown {
  position: relative;
  display: inline-block;
  cursor: pointer;
}
.dropdown .menu {
  position: absolute;
  padding-right: 1rem;
  padding-left: 1rem;
  display: none;
  width: inherit;
}
.tabs > .dropdown {
  /* padding: 1rem 2rem;
  */
  flex: 0 1 auto;
  color: var(--color-darkGrey);
  border-bottom: 2px solid var(--color-lightGrey);
  text-align: center;
}
.dropdown:hover .menu
, .dropdown:active .menu {
  display: block;
  box-shadow: var(--box-shadow);
  z-index: 2;
}
.dropdown .menu a {
  display: block;
}
.dropdown .menu a:hover {
  text-decoration: underline;
}
body>header nav:last-child {
  /*  margin-right: 0;
  */
}
body>header nav, body>footer nav {
  margin-top: 0.5rem !important;
  margin-bottom: 0.3rem !important;
}
main {
  font-size: 100%;
  padding-top: 4rem !important;
  padding-bottom: 4rem !important;
}

.card {
  border-radius: var(--border-radius);
  font-size: 80%;
}
.card p, .card h4 {
  margin: 0;
  line-height: 1.1;
}
p, h4 {
  margin-bottom:0.7rem;
  -webkit-hyphens: auto;
  -ms-hyphens: auto;
  hyphens: auto;
}
p.drop-cap::first-letter {
  float: left;
  font-size: 5rem;
  line-height: .68;
  font-weight: bold;
  /* top | right | bottom | left */
  margin: .05em .1em 0 0;
  text-transform: uppercase;
  font-family: BukyvedeRegular;
}

@media (max-width: 599px) {
  body>header  nav .tabs {
    overflow-y: scroll !important;
    -overflow-scrolling: touch !important;
    -webkit-overflow-scrolling: touch !important;
  }
   body>header nav, 
   body>footer nav {
    margin: 0 !important;
    font-size: 66% !important;
  }
  .dropdown .menu a {
    display: inline;
  }
  main {
    padding-top: 8.5rem !important;
    padding-bottom: 8.5rem !important;
  }
}

