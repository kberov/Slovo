package Slovo::Task::SendOnboardingEmail;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use feature qw(lexical_subs unicode_strings);
## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
no warnings "experimental::lexical_subs";
use Net::SMTP;
use Mojo::Util qw(b64_encode encode sha1_sum);
use Mojo::File 'path';
use Mojo::Collection 'c';

my $CONF = {};

sub send_mail_by_net_smtp ($message, $to_user, $app) {
  state $DEV = $app->mode =~ /^dev/;

  return 1 if $DEV;

  my $smtp = eval { Net::SMTP->new(%{$CONF->{'Net::SMTP'}{new}}); } or do {
    my $error = "Net::SMTP could not instantiate: $@";
    $app->log->error($error);
    Mojo::Exception->throw($error);
  };
  $smtp->auth(@{$CONF->{'Net::SMTP'}{auth}});
  $smtp->mail($CONF->{'Net::SMTP'}{mail});

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
}

# Sends a message for first login to $to_user and returns the generated token
# The token will be deleted by _delete_first_login_token($job,$token).
my sub _mail_message ($t, $from_user, $to_user, $app, $domain) {
  state $mt        = Mojo::Template->new(vars => 1);
  state $mail_body = 'task/send_onboarding_email.txt.ep';
  state $mail_tmpl = c(@{$app->renderer->paths})
    ->first(sub { -f path($_, $mail_body)->to_string; }) . "/$mail_body";

  #This token will be compared with the provided by the new user data
  #(first_name and last_name).
  my $token
    = sha1_sum($t
         . encode('UTF-8' => $from_user->{first_name} . $from_user->{last_name})
         . $from_user->{id}
         . $to_user->{id});
  my $body = $mt->render_file(
                              $mail_tmpl => {
                                    time            => $t,
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
From: $CONF->{'Net::SMTP'}{mail}
Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', $subject), '') }?=
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: 8bit
Message-Id: <acc-msg-to-$to_user->{login_name}${\ time}\@$domain>
Date: ${\ Mojo::Date->new->to_datetime }
MIME-Version: 1.0

${\ encode('UTF-8', $body)}

MAIL

  $app->debug('Message to be send:' . $/ . $message);
  send_mail_by_net_smtp($message, $to_user, $app);
  return $token;
};

# Job implementation for mail_first_login. Sends an email to the newly created
# user with a first time login link.
my sub _mail_first_login ($job, $from_user, $to_user, $domain) {
  state $app = $job->app;
  my $t     = time;
  my $token = _mail_message($t, $from_user, $to_user, $app, $domain);
  my $token_row = {
                   from_uid   => $from_user->{id},
                   to_uid     => $to_user->{id},
                   token      => $token,
                   start_date => $t,
                   stop_date  => $t + $CONF->{token_valid_for}
                  };
  $app->dbx->db->insert('first_login' => $token_row);
  $app->minion->enqueue(delete_first_login => [$to_user->{id}, $token] =>
                        {delay => $CONF->{token_valid_for}});
  $job->finish(  'Писмото за първo влизане в '
               . $domain . ' до '
               . $to_user->{first_name} . ' '
               . $to_user->{last_name}
               . ' бе успешно изпратено!');
};    ## Perl::Critic bug needs ";" at the end of private subs

# Job implementation for deleting the token record for first login of the newly
# created user.
my sub _delete_first_login ($job, $uid, $token) {
  state $app = $job->app;
  $app->dbx->db->delete('first_login' => {token => $token, to_uid => $uid});

  # also delete expired but not deleted (for any reason) login tokens.
  $app->dbx->db->delete('first_login' => {stop_date => {'<' => time}});
  $job->finish;
};

sub register ($self, $app, $conf) {
  $CONF = $self->validate_conf($conf);
  $app->minion->add_task(mail_first_login   => \&_mail_first_login);
  $app->minion->add_task(delete_first_login => \&_delete_first_login);
  return $self;
}

sub validate_conf ($self, $conf) {
  my $ME = 'Mojo::Exception';
  $ME->throw(
    q|Parameters to Net::SMT->new ('Net::SMTP'->{new}) must be a reference to hash.|
    )
    unless ref($conf->{'Net::SMTP'}{new}) eq 'HASH';
  $ME->throw(
       q|Username ('Net::SMTP'->{auth}[0]) is a mandatory configuration value.|)
    unless $conf->{'Net::SMTP'}{auth} && $conf->{'Net::SMTP'}{auth}[0];
  $ME->throw(
       q|Password ('Net::SMTP'->{auth}[1]) is a mandatory configuration value.|)
    unless $conf->{'Net::SMTP'}{auth} && $conf->{'Net::SMTP'}{auth}[1];
  $ME->throw(  q|Mail ('Net::SMTP'->{mail}) is a mandatory configuration value.|
             . 'It must be a valid email')
    unless $conf->{'Net::SMTP'}{mail}
    =~ /^[\w\-\+\.]{1,154}\@[\w\-\+\.]{1,100}$/x;
  return $conf;
}

1;

=encoding utf8

=head1 NAME

Slovo::Task::SendOnboardingEmail - Send an email with link for first time login

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

This is the first L<Minion> task implemented in L<Slovo>.

Slovo is not integrated with any social network. A plugin for such integration
can be relatively easily written and there are maybe already some
L<Mojolicious::Plugin> written.  L<Ado|https://github.com/kberov/Ado> had
L<such
functionality|https://github.com/kberov/Ado/blob/master/etc/plugins/auth.conf>
by leveraging L<Mojolicious::Plugin::OAuth2>.

Slovo takes another approach. Its users can invite each other to join the set
of sites that one Slovo instance manages. Slovo is the social network it self. We
may use L<Mojolicious::Plugin::OAuth2::Server> at some point.

A user in Slovo can create others users' accounts. Upon creation of the new
user account an email is sent to the new user. In the email there is a link for
the first time login fo the new user. The new user follows the link and is
signed in after confirming the names of the user who created his account. After
that the user has to change his password to be able to sign in next time.

Slovo::Task::SendOnboardingEmail inherits L<Mojolicious::Plugin> and implements
the following functionality.

=head1 METHODS

The following methods are implemented.

=head2 register

Reads the configuration and adds the implemented tasks to L<Minion>.

=head2 validate_conf

Validates provided in slovo.conf configuration and throws a L<Mojo::Exception>
in case some values are invalid.


=head1 FUNCTIONS

The following functions are implemented.

=head2 send_mail_by_net_smtp

Arguments: C<$message, $to_user, $app>

C<$message> must be already fully prepared and looks something like:

    my $message = <<"MAIL";
  To: $to_user->{email}
  From: $CONF->{'Net::SMTP'}{mail}
  Subject: =?UTF-8?B?${\ b64_encode(encode('UTF-8', $subject), '') }?=
  Content-Type: text/plain; charset="utf-8"
  Content-Transfer-Encoding: 8bit
  Message-Id: <acc-msg-to-$to_user->{login_name}${\ time}\@$domain>
  Date: ${\ Mojo::Date->new->to_datetime }
  MIME-Version: 1.0
  
  ${\ encode('UTF-8', $body)}
  
  MAIL

C<$to_user> is a hash reference containing at least C<$to_user-E<gt>{email}>
and C<$to_user-E<gt>{id}>.

C<$app> is the current L<Slovo> instance.

This function sends the prepared message using L<Net::SMTP>.

  $app->debug('Message to be send:' . $/ . $message);
  send_mail_by_net_smtp($message, $to_user, $app);

=head1 TASKS

The following tasks are implemented.

=head2 mail_first_login

Prepares and sends email using L<Net::SMTP> to the newly created user. The
email contains a link for the first sign in. The task is enqued upon creation
of the new account. The first time sign in is implemented in L<Slovo::Controller::Auth/first_login_form> and L<Slovo::Controller::Auth/first_login>.

=head2 delete_first_login

Deletes the record with the login token for the new user. The task is enqued by
L</mail_first_login> with delay C<token_valid_for> as configured. Defaults to
24 hours after creation of the account.

=head1 SEE ALSO

L<Slovo::Controller::Auth>, L<Slovo::Task::SendPasswEmail>.

=cut

