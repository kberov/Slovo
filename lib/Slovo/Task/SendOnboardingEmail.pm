package Slovo::Task::SendOnboardingEmail;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Net::SMTP;
use Mojo::Util qw(b64_encode encode sha1_sum steady_time);
use Mojo::File 'path';
use Mojo::Collection 'c';

my $CONF = {};

my sub _send_mail_by_net_smtp ($message, $to_user, $app) {
  state $DEV = $app->mode =~ /^dev/;

  #return 1 if $DEV;

  my $cnf  = $CONF->{smtp};
  my $smtp = eval {
    Net::SMTP->new(
                   $cnf->{mailhost},
                   Timeout => $cnf->{timeout},
                   Debug   => $DEV,
                   SSL     => $cnf->{ssl},
                   Port    => $cnf->{port},
                  );
    }
    or do {
    my $error = 'Net::SMTP could not establish connection to '
      . $cnf->{mailhost} . ": $@";
    $app->log->error($error);
    Mojo::Exception->throw($error);
    };
  $smtp->auth($cnf->{username}, $cnf->{password});
  $smtp->mail($cnf->{mail_from});

  if ($smtp->to($to_user->{email})) {
    $smtp->data;
    $smtp->datasend($message);
    $smtp->dataend();
  }
  else {
    $app->log->error('Net::SMTP Error: ' . $smtp->message());
    $app->log->error('This affects the new user with id: ' . $to_user->{id});
  }
  $smtp->quit;

  return 1;
};

# Sends a message for first login to $to_user and returns the generated token
# The token will be deleted by _delete_first_login_token($job,$token).
my sub _mail_message ($from_user, $to_user, $app, $domain) {
  state $mt            = Mojo::Template->new(vars => 1);
  state $mail_body     = 'task/send_onboarding_email.txt.ep';
  state $mail_template = c(@{$app->renderer->paths})
    ->first(sub { -f path($_, $mail_body)->to_string; }) . "/$mail_body";

  my $token = sha1_sum(steady_time . $to_user->{id});
  my $body = $mt->render_file(
                              $mail_template => {
                                    from_user       => $from_user,
                                    to_user         => $to_user,
                                    domain          => $domain,
                                    token           => $token,
                                    token_valid_for => $CONF->{token_valid_for},
                              }
                             );
  my $subject
    = 'Потребителска сметка за '
    . $to_user->{first_name} . ' '
    . $to_user->{last_name} . ' в '
    . $domain;
  my $message = <<"MAIL";
To: $to_user->{email}
From: $CONF->{smtp}{mail_from}
Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', $subject), '') }?=
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 8bit
Message-Id: <acc-msg-to-$to_user->{login_name}${\ time}\@$domain>
Date: ${\ Mojo::Date->new->to_datetime }
MIME-Version: 1.0

${\ encode('UTF-8', $body)}

MAIL

  $app->debug('Message to be send:' . $/ . $message);
  _send_mail_by_net_smtp($message, $to_user, $app);
  return $token;
};

# Job implementation for mail_first_login.
my sub _mail_first_login ($job, $from_user, $to_user, $domain) {
  state $app = $job->app;
  $app->debug('Send mail with info about first login for the created user');
  my $token = _mail_message($from_user, $to_user, $app, $domain);
  my $token_row = {
                   user_id    => $to_user->{id},
                   token      => $token,
                   start_date => time,
                   stop_date  => time + $CONF->{token_valid_for}
                  };
  $app->dbx->db->insert('first_login' => $token_row);
  $app->debug('token_row' => $token_row);
  $app->minion->enqueue(delete_first_login => [$to_user->{id}, $token] =>
                        {delay => $CONF->{token_valid_for}});
  $job->finish(  'Писмото за първo влизане в '
               . $domain . ' до '
               . $to_user->{first_name} . ' '
               . $to_user->{last_name}
               . ' бе успешно изпратено!');
};    ## Perl::Critic bug needs ";" at the end of private subs

my sub _delete_first_login ($job, $uid, $token) {
  state $app = $job->app;
  $app->debug("Deleting token $token for first login for user $uid.");
  $app->dbx->db->delete('first_login' => {token => $token, user_id => $uid});

  # also delete expired but not deleted (for any reason) login tokens.
  $app->dbx->db->delete('first_login' => {stop_date => {'<=' => time}});
  $job->finish;
};

sub register ($self, $app, $conf) {
  $CONF = $conf;
  $app->minion->add_task(mail_first_login   => \&_mail_first_login);
  $app->minion->add_task(delete_first_login => \&_delete_first_login);
}

1;

