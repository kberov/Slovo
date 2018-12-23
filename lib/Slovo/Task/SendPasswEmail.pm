package Slovo::Task::SendPasswEmail;
use Mojo::Base 'Slovo::Task::SendOnboardingEmail', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";

use Mojo::Util qw(b64_encode encode sha1_sum);
use Mojo::File 'path';
use Mojo::Collection 'c';
my $CONF = {};

# Sends a message for login with temporary password to $to_user and returns the
# generated token. The token will be deleted by
# _delete_passw_token($job,$token).
my sub _mail_message ($t, $to_user, $app, $domain) {
  state $mt        = Mojo::Template->new(vars => 1);
  state $mail_body = 'task/send_passw_email.txt.ep';
  state $mail_tmpl = c(@{$app->renderer->paths})
    ->first(sub { -f path($_, $mail_body)->to_string; }) . "/$mail_body";

  #This token will be compared with the one provided by the user.
  my $token = sha1_sum($t . encode('UTF-8' => $to_user->{id}));
  my $body = $mt->render_file(
                              $mail_tmpl => {
                                    time            => $t,
                                    to_user         => $to_user,
                                    domain          => $domain,
                                    token           => $token,
                                    token_valid_for => $CONF->{token_valid_for},
                              }
                             );
  my $subject
    = 'Временен ключ за вход за '
    . $to_user->{first_name} . ' '
    . $to_user->{last_name} . ' в '
    . $domain;
  my $message = <<"MAIL";
To: $to_user->{email}
From: $CONF->{'Net::SMTP'}{mail}
Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', $subject), '') }?=
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 8bit
Message-Id: <acc-msg-to-$to_user->{login_name}$t\@$domain>
Date: ${\ Mojo::Date->new->to_datetime }
MIME-Version: 1.0

${\ encode('UTF-8', $body)}

MAIL

  $app->debug('Message to be send:' . $/ . $message);
  Slovo::Task::SendOnboardingEmail::send_mail_by_net_smtp($message, $to_user,
                                                          $app);
  return $token;
};

my sub _mail_passw_login ($job, $to_user, $domain) {
  state $app = $job->app;
  my $t     = time;
  my $token = _mail_message($t, $to_user, $app, $domain);
  my $token_row = {
                   to_uid     => $to_user->{id},
                   token      => $token,
                   start_date => $t,
                   stop_date  => $t + $CONF->{token_valid_for}
                  };
  $app->dbx->db->insert('passw_login' => $token_row);
  $app->minion->enqueue(delete_passw_login => [$to_user->{id}, $token] =>
                        {delay => $CONF->{token_valid_for}});
  $job->finish(  'Писмото с временен ключ за влизане в '
               . $domain . ' до '
               . $to_user->{first_name} . ' '
               . $to_user->{last_name}
               . ' бе успешно изпратено!');

};

my sub _delete_passw_login ($job, $uid, $token) {
  state $app = $job->app;
  $app->dbx->db->delete('passw_login' => {token => $token, to_uid => $uid});

  # also delete expired but not deleted (for any reason) login tokens.
  $app->dbx->db->delete('passw_login' => {stop_date => {'<' => time}});
  $job->finish;
};


sub register ($self, $app, $conf) {
  $CONF = $self->validate_conf($conf);
  $app->minion->add_task(mail_passw_login   => \&_mail_passw_login);
  $app->minion->add_task(delete_passw_login => \&_delete_passw_login);
  return $self;
}


1;

