package InfoServant::Index;

use Mojo::Base 'Mojolicious::Controller';

use SiteCode::Account;

sub slash {
    my $self = shift;

    unless ($self->req->is_secure) {
        my $url = $self->url_for('/')->to_abs;
        $url->scheme('https');
        return($self->redirect_to($url));
    }

    $self->render();
}

sub login {
    my $self = shift;

    my $login = $self->param("login");
    my $password = $self->param("password");

    $self->stash(login => $login);
    $self->stash(password => $password);

    if ($self->param("added")) {
        $self->stash(success => "Successfully added: please login.");
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

    if ($self->stash('errors')) {
        return($self->render());
    }

    my $account;
    eval {
        if ($login =~ m/@/) {
            $account = SiteCode::Account->new(email => $login, password => $password);
        }
        else {
            $account = SiteCode::Account->new(username => $login, password => $password);
        }
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
        $self->session(account_username => $account->username());
        $self->session(account_id => $account->id());
        $self->session(account_email => $account->email());
        my $url = $self->url_for('/dashboard');
        return($self->redirect_to($url));
    }
}

1;
