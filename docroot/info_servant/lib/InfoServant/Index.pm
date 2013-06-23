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

package InfoServant::Index;

use Mojo::Base 'Mojolicious::Controller';

use Digest::MD5;
use SiteCode::Account;
use Email::Valid;

sub slash {
    my $self = shift;

    unless ($self->req->is_secure) {
        my $url = $self->url_for('/')->to_abs;
        $url->scheme('https');
        return($self->redirect_to($url));
    }

    if ($self->session->{account_id}) {
        my $url = $self->url_for('/dashboard');
        return($self->redirect_to($url));
    }

    $self->render();
}

sub login {
    my $self = shift;

    my $login = $self->param("login");
    my $password = Digest::MD5::md5_hex($self->param("password"));

    $self->stash(login => $login);

    if ($self->param("added")) {
        $self->stash(success => "Added: please see verificaiton email.");
        return($self->render());
    }

    if ($self->flash("verify")) {
        $self->stash(success => "Please login to verify.");
        $self->session(verify => $self->flash("verify"));
        return($self->render());
    }

    if (!$login) {
        # $self->stash(errors => "No login given.");
        return($self->render());
    }

    if (!$password) {
        # $self->stash(errors => "No password given.");
        return($self->render());
    }

    if (!Email::Valid->address($login)) {
        $self->stash(errors => "Email address not valid.");
    }

    if ($self->stash('errors')) {
        return($self->render());
    }

    my $account;
    eval {
        $account = SiteCode::Account->new(email => $login, password => $password, route => $self);
    };
    if ($@) {
        my $err = $@;
        if ($err =~ m/line\s*\d+\D*\n\z/) {
            $self->app->log->debug("InfoServant::Index::login: $err");
            $self->stash(errors => "An unknown error occurred.");

            return $self->render();
        }
        else {
            $self->stash(errors => $err);

            return $self->render();
        }
    }

    if ($self->stash('errors')) {
        return($self->render());
    }
    else {
        $self->session(account_id => $account->id());
        $self->session(account_email => $account->email());
        $self->session(expiration => 604800);
        my $url = $self->url_for('/dashboard');
        return($self->redirect_to($url));
    }
}

1;
