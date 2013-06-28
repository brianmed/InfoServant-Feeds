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

    my $errors = "";
    if (!$email) {
        $errors = "Please enter an email.";
    }
    if (!$errors && !$username) {
        $errors = "Please enter a username.";
    }
    if (!$errors && !$password) {
        $errors = "Please enter a password.";
    }

    $self->stash(errors => $errors);

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

    eval {
        $account = SiteCode::Account->addUser(
            email => $email,
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
            $self->stash(errors => "An unknown error occurred.");

            return $self->render("signup/start");
        }
        else {
            $self->stash(errors => $err);

            return $self->render("signup/start");
        }
    }
    else {
        $self->stash(success => "Please login.");
        $url = $self->url_for('/login')->query(login => $account->email, added => 1);
        return $self->redirect_to($url);
    }

    $self->app->log->debug("add: last");
}

sub verify
{
    my $self = shift;

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
        $self->stash(errors => "Please enter a verification code.");
    }
    elsif ($verify) {
        $self->stash(errors => "Please enter an email.");
    }

    $self->render();
}

1;
