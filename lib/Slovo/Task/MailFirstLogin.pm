package Slovo::Task::MailFirstLogin;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

my sub _mail_first_login ($job, $user) {
  $job->app->debug(
                  'Send mail with info about first login for the created user');
              $job->finish('Mail to user with id'.$user->{id}.' was send!');
};    ## Perl::Critic bug needs ";" at the end of private subs

sub register($self, $app, $conf) {
  $app->minion->add_task(mail_first_login => \&_mail_first_login);
}


1;

