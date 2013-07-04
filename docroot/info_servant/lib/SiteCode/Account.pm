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

package SiteCode::Account;

use SiteCode::Modern;

use Moose;
use namespace::autoclean;
use Moose::Util::TypeConstraints;

use Email::Valid;
use Digest::MD5;
use POSIX;

use SiteCode::DBX;
use SiteCode::Site;

subtype 'Email'
    => as 'Str'
    => where { Email::Valid->address($_) }
    => message { $_ ? "$_ is not a valid email address" : "No value given for address validation" };

has 'id' => ( isa => 'Int', is => 'rw' );
has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', lazy => 1, default => sub { SiteCode::DBX->new() } );

has 'email' => ( isa => 'Email', is => 'rw' );
has 'username' => ( isa => 'Str', is => 'rw' );
has 'password' => ( isa => 'Str', is => 'rw' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );

sub _lookup_id_with_email {
    my $self = shift;

    return($self->dbx()->col("SELECT id FROM account WHERE email = ?", undef, $self->email()));
}

sub _lookup_id_with_username {
    my $self = shift;

    return($self->dbx()->col("SELECT id FROM account WHERE username = ?", undef, $self->username()));
}

sub _lookup_email {
    my $self = shift;

    return($self->dbx()->col("SELECT email FROM account WHERE id = ?", undef, $self->id()));
}

sub _lookup_password {
    my $self = shift;

    return($self->dbx()->col("SELECT password FROM account WHERE id = ?", undef, $self->id()));
}

sub _lookup_username {
    my $self = shift;

    return($self->dbx()->col("SELECT username FROM account WHERE id = ?", undef, $self->id()));
}

sub _verify_id_and_email {
    my $self = shift;

    return($self->dbx()->success("SELECT 1 FROM account WHERE id = ? AND email = ? AND username = ?", undef, $self->id(), $self->email(), $self->username()));
}

sub BUILD {
    my $self = shift;

    eval {
        if ($self->id()) {
            $self->email($self->_lookup_email());
            $self->password($self->_lookup_password());
            $self->username($self->_lookup_username());
        }
        elsif ($self->email() && !$self->username()) {
            $self->id($self->_lookup_id_with_email());
            $self->username($self->_lookup_username());
        }
        elsif ($self->username() && !$self->email()) {
            $self->id($self->_lookup_id_with_username());
            $self->email($self->_lookup_email());
        }
    };
    if ($@) {
        $self->route->app->log->debug("InfoServant::Index::login: $@");
        die("Invalid credentials.\n");
    }

    if (!$self->id() && !$self->email()) {
        die("No id or email given.\n");
    }

    unless ($self->id() && $self->email()) {
        die("Need both id and email.\n");
    }

    unless ($self->_verify_id_and_email()) {  # verify our looked up columns
        die("The given id, email, and username do not match.\n");
    }

    unless($self->chkPw($self->password())) {
        die("Credentials mis-match.\n");
    }
}

sub addUser
{
    my $self = shift;
    my %ops = @_;

    my $email = $ops{email};
    my $username = $ops{username};
    my $password = $ops{password};

    my $time = time();
    my $md5 = Digest::MD5::md5_hex($time);
    my $password_md5 = Digest::MD5::md5_hex($password);

    my $account;

    eval {
        my $dbx = SiteCode::DBX->new(route => $ops{route});

        my $count = $dbx->col("select count(id) from account", undef);
        if (10_000 < $count) {
            die "Too many active accounts. Please come back soon.\n";
        }

        my $taken = $dbx->success("SELECT 1 FROM account WHERE email = ?", undef, lc $email);
        if ($taken) {
            die "Email already taken.\n";
        }

        $taken = $dbx->success("SELECT 1 FROM account WHERE username = ?", undef, $username);
        if ($taken) {
            die "Username already taken.\n";
        }

        my $exists = $dbx->success("SELECT 1 FROM account WHERE email = ? AND password = ?", undef, lc $email, $password);
        if ($exists) {
            my $verified = $self->key("verified");
            if ($verified) {
                if ("SUCCESS" eq $verified) {
                    die "User already verified.\n";
                }
                else {
                    die "User waiting verification.\n";
                }
            }
        }

        $dbx->do("INSERT INTO account (email, username, password) VALUES (?, ?, ?)", undef, lc $email, $username, $password_md5);
        $dbx->dbh->commit;

        my $id = $dbx->col("SELECT id FROM account WHERE email = ?", undef, lc $email);
        $account = SiteCode::Account->new(id => $id, password => $password_md5);
        $account->key("verified", $md5);
    };
    if ($@) {
        die($@);
    }

    return($account);
}

sub key
{
    my $self = shift;
    my $key = shift;

    my $dbx = SiteCode::DBX->new();

    if (scalar(@_)) {
        if (defined $_[0]) {
            my $value = shift;
            my $defined = $self->key($key);

            if ($defined) {
                my $id = $dbx->col("SELECT id FROM account_key WHERE account_id = ? AND account_key = ?", undef, $self->id(), $key);
                $dbx->do("UPDATE account_value SET account_value = ? WHERE account_key_id = ?", undef, $value, $id);

                $dbx->dbh->commit;
            }
            else {
                $dbx->do("INSERT INTO account_key (account_id, account_key) VALUES (?, ?)", undef, $self->id(), $key);
                my $id = $dbx->col("SELECT id FROM account_key WHERE account_id = ? AND account_key = ?", undef, $self->id(), $key);
                $dbx->do("INSERT INTO account_value (account_key_id, account_value) VALUES (?, ?)", undef, $id, $value);

                $dbx->dbh->commit;
            }
        }
        else {
            my $defined = $self->key($key);

            if ($defined) {
                my $id = $dbx->col("SELECT id FROM account_key WHERE account_id = ? AND account_key = ?", undef, $self->id(), $key);
                $dbx->do("DELETE FROM account_key where id = ?", undef, $id);

                $dbx->dbh->commit;
            }
        }
    }

    my $row = $dbx->row(qq(
        SELECT 
            account_key, account_value 
        FROM 
            account_key, account_value 
        WHERE account_key = ?
            AND account_id = ?
            AND account_key.account_id = account_id
            AND account_key.id = account_value.account_key_id
    ), undef, $key, $self->id());

    my $ret = $row->{account_value};
    return($ret);
}

sub sendVerifyEmail
{
    my $self = shift;
    my %ops = @_;

    my $email = $self->email;
    my $md5 = $self->key("verified");

    require Email::Simple;
    require Email::Sender::Simple;
    require Email::Sender::Transport::SMTP::TLS;

    Email::Sender::Simple->import("sendmail");

    my $mail = Email::Simple->create(
        header => [
            To      => $email,
            From    => 'signup@infoservant.com',
            Subject => "Welcome to InfoServant",
        ],
        body => "Thank you for signing up with InfoServant.\nPlease follow the link below to verify your email address:\n\nEmail: $email\nVerification number: $md5\n\nhttp://infoservant.com/verify/$email/$md5\n",
    );

    my $site_config = SiteCode::Site->config();
    my $dir = POSIX::strftime("$$site_config{site_dir}/emails/%F", localtime(time));
    mkdir $dir unless -d $dir;
    my ($fh, $filename) = File::Temp::tempfile("verifyXXXXX", DIR => $dir, SUFFIX => '.txt', UNLINK => 0);
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

sub chkPw
{
    my $self = shift;
    my $pw = shift;

    my $ret = $self->dbx()->col("SELECT password FROM account WHERE id = ?", undef, $self->id());

    return($pw eq $ret);
}

sub exists {
    my $class = shift;

    my %opt = @_;

    if ($opt{email}) {
        return(SiteCode::DBX->new()->col("SELECT id FROM account WHERE email = ?", undef, lc $opt{email}));
    }
}

sub verify {
    my $self = shift;
    my $v = shift;

    my $verify = $self->key("verified");
    if ("SUCCESS" eq $verify) {
        return("ALREADY_VERIFIED");
    }

    if ($v eq $verify) {
        $verify = $self->key("verified", "SUCCESS");
        return("VERIFIED");
    }

    return('');
}

sub verified {
    my $self = shift;

    my $verified = $self->key("verified");
    if ("SUCCESS" eq $verified) {
        return(1);
    }
    else {
        return(0);
    }
}

__PACKAGE__->meta->make_immutable;

1;
