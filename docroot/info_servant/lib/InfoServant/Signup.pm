package InfoServant::Signup;

use Mojo::Base 'Mojolicious::Controller';

use SiteCode::Account;

sub start {
    my $self = shift;

    $self->app->log->debug("signup: start");

    $self->render();
}

sub restart {
    my $self = shift;

    my $username = $self->param("username");
    my $email = $self->param("email");
    my $vemail = $self->param("vemail");
    my $password = $self->param("password");

    my $errors = "";
    if (!$username) {
        $errors .= $errors ? "<br>" : "";
        $errors .= "Please enter a username";
    }
    if (!$email) {
        $errors .= $errors ? "<br>" : "";
        $errors .= "Please enter an email";
    }
    if (!$vemail) {
        $errors .= $errors ? "<br>" : "";
        $errors .= "Please enter a verification email";
    }
    if (!$password) {
        $errors .= $errors ? "<br>" : "";
        $errors .= "Please enter a password";
    }

    $self->stash(errors => $errors);

    $self->stash(username => $username);
    $self->stash(email => $email);
    $self->stash(vemail => $vemail);
    $self->stash(password => $password);

    $self->render("signup/start");
}

sub add {
    my $self = shift;

    my ($account, $url);

    my $username = $self->param("username");
    my $email = $self->param("email");
    my $vemail = $self->param("vemail");
    my $password = $self->param("password");

    $self->app->log->debug("InfoServant::Signup::add");

    if ($email ne $vemail) {
        $self->stash(errors => "Email verification does not match.");

        return $self->render("signup/start");
    }

    eval {
        $account = SiteCode::Account->addUser(
            username => $username,
            email => $email,
            password => $password,
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
        $self->stash(success => "Successfully added user: please login.");
        $url = $self->url_for('/login')->query(login => $account->username, added => 1);
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
