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

1;
