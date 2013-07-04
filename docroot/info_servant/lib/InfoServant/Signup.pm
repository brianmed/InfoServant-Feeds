#
# InfoServant - Your information, delivered.
# Copyright (C) 2013 Brian Medley
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package InfoServant::Signup;

use Mojo::Base 'Mojolicious::Controller';

use SiteCode::Account;
use SiteCode::DBX;
use SiteCode::Site;
use Digest::MD5;

sub start {
    my $self = shift;

    $self->render();
}

sub restart {
    my $self = shift;

    my $email = $self->param("email");
    my $username = $self->param("username");
    my $password = $self->param("password");

    my $error = "";
    if (!$email) {
        $error = "Please enter an email.";
    }
    if (!$error && !$username) {
        $error = "Please enter a username.";
    }
    if (!$error && !$password) {
        $error = "Please enter a password.";
    }

    $self->stash(error => $error);

    $self->stash(email => $email);
    $self->stash(username => $username);
    $self->stash(password => $password);

    $self->render("signup/start");
}

sub add {
    my $self = shift;

    my ($account, $url);

    my $email = $self->param("email");
    my $username = $self->param("username");
    my $password = $self->param("password");

    $self->stash(email => $self->param("email"));
    $self->stash(username => $self->param("username"));
    $self->stash(password => $self->param("password"));

    if (Email::Valid->address($username)) {
        $self->stash(error => "Username looks like an email address.");

        return $self->render("signup/start");
    }

    if (!Email::Valid->address($email)) {
        $self->stash(error => "Email address looks invalid.");

        return $self->render("signup/start");
    }

    if (length($username) < 3) {
        $self->stash(error => "Username less than 3 characters.");

        return $self->render("signup/start");
    }

    if (length($password) < 5) {
        $self->stash(error => "Password less than 6 characters.");

        return $self->render("signup/start");
    }

    eval {
        $account = SiteCode::Account->addUser(
            email => $email,
            username => $username,
            password => $password,
            route => $self,
        );

        $account->sendVerifyEmail();

        $self->stash(info => "Signup email sent.");
    };
    if ($@) {
        my $err = $@;
        if ($err =~ m/line\s*\d+\D*\n\z/) {
            $self->app->log->debug("InfoServant::Signup::add: $err");
            $self->stash(error => "An unknown error occurred.");

            return $self->render("signup/start");
        }
        else {
            $self->stash(error => $err);

            return $self->render("signup/start");
        }
    }
    else {
        $self->stash(success => "Please login.");
        $url = $self->url_for('/login')->query(login => $account->email, added => 1);
        return $self->redirect_to($url);
    }
}

sub verify
{
    my $self = shift;

    if ("GET" eq $self->req->method) {
        return($self->render());
    }

    my $email = $self->stash("email") || $self->param("email");
    my $verify = $self->stash("verify") || $self->param("verify");

    $self->stash(email => $self->param("email"));
    $self->stash(verify => $self->param("verify"));

    if ($email && $verify) {
        $self->flash(verify => $self->param("verify"));

        my $url = $self->url_for('/login')->query(login => $email);
        $self->redirect_to($url);
    }
    elsif ($email) {
        $self->stash(error => "Please enter a verification code.");
    }
    elsif ($verify) {
        $self->stash(error => "Please enter an email.");
    }
    else {
        $self->stash(error => "Please enter a verification code.");
    }

    $self->render();
}

sub change {
    my $self = shift;

    my $email = $self->param("email");
    my $username = $self->param("username");
    my $verify = $self->param("verify");
    my $password = $self->param("password");

    $self->stash(email => $email);
    $self->stash(username => $username);
    $self->stash(verify => $verify);

    if ("GET" eq $self->req->method) {
        my $exists = SiteCode::DBX->new()->col("SELECT id FROM account WHERE email = ?", undef, lc $email);
        if ($exists) {
            my $account = SiteCode::Account->new(id => $exists, route => $self);
            my $value = $account->key("reset");
            if ($value eq $verify) {
                $self->stash(username => $account->username);
            }
        }

        return($self->render());
    }

    if (!$email) {
        $self->stash(error => "No email address given.");
        return($self->render());
    }

    unless (Email::Valid->address($email)) {
        $self->stash(error => "Email address looks invalid.");
    }

    if (!$username) {
        $self->stash(error => "No username given.");
        return($self->render());
    }

    if (!$verify) {
        $self->stash(error => "No verification given.");
        return($self->render());
    }

    if (length($password) < 5) {
        $self->stash(error => "Password less than 6 characters.");

        return $self->render();
    }

    my $dbx = SiteCode::DBX->new();
    my $exists = $dbx->col("SELECT id FROM account WHERE email = ? AND username = ?", undef, lc $email, $username);
    if ($exists) {
        my $account = SiteCode::Account->new(id => $exists, route => $self);

        my $value = $account->key("reset");
        if ($value eq $verify) {
            my $password_md5 = Digest::MD5::md5_hex($password);
            eval {
                $dbx->do("UPDATE account SET password = ? WHERE id = ?", undef, $password_md5, $exists);
                $account->key("reset", undef);
                $dbx->dbh->commit;
                $self->stash(success => "Password updated.");
            };
            if ($@) {
                $self->app->log->debug("InfoServant::Signup::change: $@");
                $dbx->dbh->rollback;
            }
        }
    }

    $self->stash(info => "Password not updated.") unless $self->stash("success");

    $self->render();
}

sub reset {
    my $self = shift;

    if ("GET" eq $self->req->method) {
        return($self->render());
    }

    my $email = $self->param("email");
    my $username = $self->param("username");

    $self->stash(email => $email);
    $self->stash(username => $username);

    if (!$email) {
        $self->stash(error => "No email address given.");
        return($self->render());
    }
    if (!$username) {
        $self->stash(error => "No username given.");
        return($self->render());
    }

    my $exists;
    unless (Email::Valid->address($email)) {
        $self->stash(error => "Email address looks invalid.");
        return($self->render());
    }
    else {
        $exists = SiteCode::DBX->new()->col("SELECT id FROM account WHERE email = ? AND username = ?", undef, lc $email, $username);
    }

    if ($exists) {
        my $account = SiteCode::Account->new(id => $exists, route => $self);

        my $time = time();
        my $md5 = Digest::MD5::md5_hex($time);

        $account->key("reset", $md5);

        # Libraries?
        require Email::Simple;
        require Email::Sender::Simple;
        require Email::Sender::Transport::SMTP::TLS;

        Email::Sender::Simple->import("sendmail");

        my $mail = Email::Simple->create(
            header => [
                To      => $email,
                From    => 'reset@infoservant.com',
                Subject => "Password Reset",
            ],
            body => "Thank you for using InfoServant.\nPlease follow the link below to change your password:\n\nhttp://infoservant.com/reset/$email/$md5\n",
        );

        my $site_config = SiteCode::Site->config();
        my $dir = POSIX::strftime("$$site_config{site_dir}/emails/%F", localtime(time));
        mkdir $dir unless -d $dir;
        my ($fh, $filename) = File::Temp::tempfile("forgotXXXXX", DIR => $dir, SUFFIX => '.txt', UNLINK => 0);
        print($fh $mail->as_string);

        my $site_config = SiteCode::Site->config();
        my $transport = Email::Sender::Transport::SMTP::TLS->new({
                host => $site_config->{smtp_host},
                port => $site_config->{smtp_port},
                username => $site_config->{smtp_user},
                password => $site_config->{smtp_pass},
        });
        sendmail($mail, {transport => $transport });
    }

    $self->stash(success => "Sending reset form.");

    $self->render();
}

1;
