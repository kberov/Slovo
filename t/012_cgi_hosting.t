use Mojo::Base -strict;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::More;
use Test::Mojo;
use Mojo::File qw(path);
use Mojo::Util qw(decode punycode_decode punycode_encode);

unless ($ENV{SLOVO_DOCUMENT_ROOT} && $ENV{TEST_AUTHOR}) {
  plan(
    skip_all => qq'
Author end to end test.
Set \$ENV{TEST_AUTHOR}, \$ENV{SLOVO_DOCUMENT_ROOT}, \$ENV{SLOVO_DOM}.
For example:
    export TEST_AUTHOR=1
    export SLOVO_DOM="xn--b1arjbl.xn--90ae"
    export SLOVO_DOCUMENT_ROOT="\$HOME/opt/\$SLOVO_DOM"

Add a record to your /etc/hosts file, for example:
127.0.1.1	dev.xn--b1arjbl.xn--90ae www.xn--b1arjbl.xn--90ae qa.xn--b1arjbl.xn--90ae

Configure a virtual host in Apache2 with document root \$SLOVO_DOCUMENT_ROOT
and run this test.
NOTE: You may need to use `sudo` to delete existng files created by Apache.

See example domain configuration at the end of this test file:
${\ __FILE__}.
'
  );
}

my $install_dir = "$ENV{SLOVO_DOCUMENT_ROOT}/slovo";
my $t           = Test::Mojo->with_roles('+Slovo')->install(

# from => to
  "$Bin/.." => $install_dir,

# Directories permissions
  0777
)->new('Slovo');
my $app     = $t->app;
my $moniker = $app->moniker;
my $mode    = $app->mode;
my $home    = $app->home;
note $home;

my $Deploy = sub {
  my $buffer = '';
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;

    $app->commands->run(
      generate  => 'novy_dom',
      '--name'  => $ENV{SLOVO_DOM},
      '--chmod' => 0777
    );
    $app->commands->run(generate => 'cgi_script');
    $app->commands->run(generate => 'a2htaccess');
    note $buffer;

    # Only for the purpose of this test! Not in production! Use mod_suexec there.
    # Make sure database file is writable by Apache
    my $db = $app->resources->child("data/$moniker.$mode.sqlite")->chmod(0646);
    ok((($db->stat->mode & 006) == 006) => "$db is writable by apache");
    my $dir = $db->dirname;
    $dir->chmod(0777);
    ok((($dir->stat->mode & 006) == 006) => "$dir is writable by apache");

    # Make sure public dir is writable by Apache
    my $public = $home->child("domove/$ENV{SLOVO_DOM}/public")->chmod(0777);
    ok((($public->stat->mode & 006) == 006) => "$public is writable by apache");
    $app->commands->run(generate => 'cgi_script');
    $app->commands->run(generate => 'a2htaccess');
  }
  cmp_ok($home, 'eq', $install_dir, 'proper installation directory');
  like $buffer => qr/mkdir.+\/$ENV{SLOVO_DOM}/mx => 'domain folder created';
  like $buffer => qr|write.+/.+slovo.cgi|mx      => 'cgi_script created';
  my ($cgi_file) = $buffer =~ m|write.+($install_dir/slovo\.cgi)|;
  ok -f $cgi_file => "$cgi_file exists";
  like $buffer => qr/(?:write|exist).+\/.htaccess/ => '.htaccess created';
  my ($hta_file)
    = $buffer =~ m"(?:write|exists)\]\s+($ENV{SLOVO_DOCUMENT_ROOT}/.htaccess)";
  path($hta_file)->chmod(0644);
  ok -f $hta_file => "$hta_file exists";
};

my $dev_dom = "http://dev."
  . (join '.', map { punycode_decode $_= s/xn--//r } split m'\.', $ENV{SLOVO_DOM});
note $dev_dom;
my $htaccess_default = sub {

  # DirectoryIndex
  $t->get_ok("$dev_dom")->status_is(200)
    ->text_is('#content-wrapper h1' => 'Добре дошли!', 'right h1')
    ->text_is('title'               => 'Добре дошли!', 'right title');

  # SCRIPT_NAME
  $t->get_ok("$dev_dom/$moniker/$moniker.cgi")->status_is(200)
    ->text_is('#content-wrapper h1' => 'Добре дошли!', 'right h1')
    ->text_is('title'               => 'Добре дошли!', 'right title');

  # ErrorDocument
  $t->get_ok("$dev_dom/alabalanica.html")->status_is(404)
    ->text_is('#content-wrapper h1' => 'Страницата не е намерена', 'right h1')
    ->text_is('title'               => 'Страницата не е намерена', 'right title');
};
my $RewriteRules = sub {

  # RewriteCond %{REQUEST_FILENAME} favicon.ico [NC]
  # RewriteRule .* - [END]
  $t->get_ok("$dev_dom/favicon.ico")->status_is(200);

  # Do not apply rules when requesting "<%=$cgi_script%>"
  #RewriteCond %{SCRIPT_FILENAME} <%=$cgi_script%> [NC]
  #RewriteRule .* - [NE,NS,END]
  $t->get_ok("$dev_dom/$moniker/$moniker.cgi")->status_is(200)
    ->text_is('#content-wrapper h1' => 'Добре дошли!', 'right h1')
    ->text_is('title'               => 'Добре дошли!', 'right title');

  # Redirect all requests for Slovo static files to respective domain's public/ directory.
  # /css/fonts.css -> /domove/t.com/public/css/fonts.css
  #RewriteCond %{REQUEST_FILENAME} !-f
  #RewriteCond %{REQUEST_FILENAME} !-d
  # Match xn--b1arjbl.xn--90ae out of www.xn--b1arjbl.xn--90ae
  #RewriteCond %{HTTP_HOST} ([\w\-]+.[\w\-]+)$
  #RewriteRule ^((?:css|img|js|fonts)/.+)$  /<%=$moniker%>/domove/%1/public/$1 [NE,END]
  $t->get_ok("$dev_dom/css/site.css")->status_is(200)
    ->content_like(qr'Body CSS', 'right CSS')->content_type_is('text/css');

# t.com/about-en-us.html becomes t.com/domove/t.com/public/cached/about-en-us.html
#RewriteCond %{REQUEST_FILENAME} !-f
#RewriteCond %{REQUEST_FILENAME} !-d
#RewriteCond %{HTTP_HOST} ([\w\-]+.[\w\-]+)$
#RewriteRule ^(.+(?!\.cgi).+\.html)$  /<%=$moniker%>/domove/%1/public/cached/$1 [NE,NS,END]
  $t->get_ok("$dev_dom/ѿносно.bg-bg.html")->status_is(200)
    ->text_is('#content-wrapper h1' => 'Ѿносно', 'right h1')
    ->text_is('title'               => 'Ѿносно', 'right title');

  # GET /коренъ.bg-bg.html
  $t->get_ok("$dev_dom/коренъ.bg-bg.html")->status_is(200)
    ->text_is('#content-wrapper h1' => 'Добре дошли!', 'right h1')
    ->text_is('title'               => 'Добре дошли!', 'right title');
};
my $POST = sub {
  $t->login_ok('', '', $dev_dom);
};
subtest 'Deploy domain'         => $Deploy;
subtest 'htaccess default'      => $htaccess_default;
subtest 'htaccess RewriteRules' => $RewriteRules;
subtest 'POST'                  => $POST;
done_testing;

__DATA__

@001_xn--b1arjbl.xn--90ae.conf

<VirtualHost 127.0.1.1:80>
	ServerName xn--b1arjbl.xn--90ae
	ServerAlias dev.xn--b1arjbl.xn--90ae www.xn--b1arjbl.xn--90ae qa.xn--b1arjbl.xn--90ae
	ServerAdmin webmaster@xn--b1arjbl.xn--90ae
	DocumentRoot /home/berov/opt/xn--b1arjbl.xn--90ae
	<Directory "/home/berov/opt/xn--b1arjbl.xn--90ae">
	    AllowOverride All
	    Require all granted
	</Directory>

	# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
	# error, crit, alert, emerg. It is also possible to configure the loglevel
	# for particular modules, e.g. LogLevel info ssl:warn
	LogLevel info authz_core:error rewrite:trace1

	ErrorLog ${APACHE_LOG_DIR}/xn--b1arjbl.xn--90ae.error.log
	CustomLog ${APACHE_LOG_DIR}/xn--b1arjbl.xn--90ae.access.log combined
</VirtualHost>
