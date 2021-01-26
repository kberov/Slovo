package Slovo::Task::SendPasswEmail;
use Mojo::Base 'Slovo::Task::SendOnboardingEmail', -signatures;

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
  state $mail_tmpl
    = c(@{$app->renderer->paths})->first(sub { -f path($_, $mail_body)->to_string; })
    . "/$mail_body";

  #This token will be compared with the one provided by the user.
  my $token = sha1_sum($t . encode('UTF-8' => $to_user->{id}));
  my $body  = $mt->render_file(
    $mail_tmpl => {
      time            => $t,
      to_user         => $to_user,
      domain          => $domain,
      token           => $token,
      token_valid_for => $CONF->{token_valid_for},
    });
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
  Slovo::Task::SendOnboardingEmail::send_mail_by_net_smtp($message, $to_user, $app);
  return $token;
}

my sub _mail_passw_login ($job, $to_user, $domain) {
  state $app = $job->app;
  my $t         = time;
  my $token     = _mail_message($t, $to_user, $app, $domain);
  my $token_row = {
    to_uid     => $to_user->{id},
    token      => $token,
    start_date => $t,
    stop_date  => $t + $CONF->{token_valid_for}};
  $app->dbx->db->insert('passw_login' => $token_row);
  $app->minion->enqueue(
    delete_passw_login => [$to_user->{id}, $token] => {delay => $CONF->{token_valid_for}}
  );
  return $job->finish('Писмото с временен ключ за влизане в '
      . $domain . ' до '
      . $to_user->{first_name} . ' '
      . $to_user->{last_name}
      . ' бе успешно изпратено!');

}

my sub _delete_passw_login ($job, $uid, $token) {
  state $app = $job->app;
  $app->dbx->db->delete('passw_login' => {token => $token, to_uid => $uid});

  # also delete expired but not deleted (for any reason) login tokens.
  $app->dbx->db->delete('passw_login' => {stop_date => {'<' => time}});
  return $job->finish;
}


sub register ($self, $app, $conf) {
  $CONF = $self->validate_conf($conf);
  $app->minion->add_task(mail_passw_login   => \&_mail_passw_login);
  $app->minion->add_task(delete_passw_login => \&_delete_passw_login);
  return $self;
}

1;

=encoding utf8

=head1 NAME

Slovo::Task::SendPasswEmail - sends email to user containing one time password.

=head1 SYNOPSIS

  # common configuration for similar Tasks in slovo.conf
  my $mail_cfg = {
    token_valid_for => 24 * 3600,
    'Net::SMTP'     => {
      new => {
        Host => 'mail.example.org',

        #Debug          => 1,
        SSL             => 1,
        SSL_version     => 'TLSv1',
        SSL_verify_mode => 0,
        Timeout         => 60,
             },
      auth => ['slovo@example.org', 'Pa55w03D'],
      mail => 'slovo@example.org',
    },
  };

  #load the plugin via slovo.conf
  plugins => [
    #...
    #Tasks
    {'Task::SendOnboardingEmail' => $mail_cfg},
    {'Task::SendPasswEmail'      => $mail_cfg},
  ],

=head1 DESCRIPTION

Slovo::Task::SendPasswEmail extends L<Slovo::Task::SendOnboardingEmail>. This
is poor design, but quick and working solution for now. It implements tasks for
sending email for forgotten password and for deleting the temporary password.



=head1 METHODS

The following methods are implemented.

=head2 register

Reads the configuration and adds the implemented tasks to L<Minion>.

=head1 TASKS

The following tasks are implemented.

=head2 mail_passw_login

Sends an email containing one time password to users who claim they forgot
their password.  It uses
L<Slovo::Task::SendOnboardingEmail/send_mail_by_net_smtp> to send the mail. The
taks is invoked by action L<Slovo::Controller::Auth/lost_password_form>

Arguments: C<$job, $to_user, $domain>.

C<job> is the job object provided by L<Minion>. C<$to_user> is a hash reference
containing the user properties found in a C<users> table record. C<$domain> is
the current domain.

  my $job_id = $c->minion->enqueue(
                     mail_passw_login => [$user, $c->req->headers->host]);

=head2 delete_passw_login

Arguments: C<$job, $uid, $token>.

Invoked by L</mail_passw_login>. Deletes the temporary password after delay
C<$CONF-E<gt>{token_valid_for}>.

  $app->minion->enqueue(delete_passw_login => [$to_user->{id}, $token] =>
                        {delay => $CONF->{token_valid_for}});

=head1 SEE ALSO

L<Slovo::Controller::Auth>, L<Slovo::Task::SendOnboardingEmail>.

=cut

