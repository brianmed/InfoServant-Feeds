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

use Moose;
use namespace::autoclean;

use SiteCode::DBX;
use Email::Valid;
use Moose::Util::TypeConstraints;
use Digest::MD5;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;

use SiteCode::Site;

subtype 'Email'
    => as 'Str'
    => where { Email::Valid->address($_) }
    => message { $_ ? "$_ is not a valid email address" : "No value given for address validation" };

has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', default => sub { SiteCode::DBX->new() } );
has 'id' => ( isa => 'Int', is => 'rw' );
has 'email' => ( isa => 'Email', is => 'rw' );
has 'password' => ( isa => 'Str', is => 'rw' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );

sub _lookup_id_with_email {
    my $self = shift;

    return($self->dbx()->col("SELECT id FROM account WHERE email = ?", undef, $self->email()));
}

sub _lookup_email {
    my $self = shift;

    return($self->dbx()->col("SELECT email FROM account WHERE id = ?", undef, $self->id()));
}

sub _lookup_password {
    my $self = shift;

    return($self->dbx()->col("SELECT password FROM account WHERE id = ?", undef, $self->id()));
}

sub _verify_id_and_email {
    my $self = shift;

    return($self->dbx()->success("SELECT 1 FROM account WHERE id = ? AND email = ?", undef, $self->id(), $self->email()));
}

sub BUILD {
    my $self = shift;

    eval {
        if ($self->id()) {
            $self->email($self->_lookup_email());
            $self->password($self->_lookup_password());
        }
        elsif ($self->email() && !$self->id()) {
            $self->id($self->_lookup_id_with_email());
        }
    };
    if ($@) {
        die("Invalid credentials.\n");
    }

    if (!$self->id() && !$self->email()) {
        die("No id or email given.\n");
    }

    unless ($self->id() && $self->email()) {
        die("Need both id and email.\n");
    }

    unless ($self->_verify_id_and_email()) {  # verify our looked up columns
        die("The given id and email do not match.\n");
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
    my $password = $ops{password};

    my $time = time();
    my $md5 = Digest::MD5::md5_hex($time);
    my $password_md5 = Digest::MD5::md5_hex($password);

    my $account;

    eval {
        my $dbx = SiteCode::DBX->new(route => $ops{route});

        my $taken = $dbx->success("SELECT 1 FROM account WHERE email = ?", undef, lc $email);
        if ($taken) {
            die "Email already taken.\n";
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

        $dbx->do("INSERT INTO account (email, password) VALUES (?, ?)", undef, lc $email, $password_md5);

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
    my $value = shift;

    my $dbx = SiteCode::DBX->new();

    if ($value) {
        my $defined = $self->key($key);

        if ($defined) {
            my $id = $dbx->col("SELECT id FROM user_key WHERE account_id = ? AND user_key = ?", undef, $self->id(), $key);
            $dbx->do("UPDATE user_value SET user_value = ? WHERE user_key_id = ?", undef, $value, $id);
        }
        else {
            $dbx->do("INSERT INTO user_key (account_id, user_key) VALUES (?, ?)", undef, $self->id(), $key);
            my $id = $dbx->col("SELECT id FROM user_key WHERE account_id = ? AND user_key = ?", undef, $self->id(), $key);
            $dbx->do("INSERT INTO user_value (user_key_id, user_value) VALUES (?, ?)", undef, $id, $value);
        }
    }

    my $row = $dbx->row(qq(
        SELECT 
            user_key, user_value 
        FROM 
            user_key, user_value 
        WHERE user_key = ?
            AND account_id = ?
            AND user_key.account_id = account_id
            AND user_key.id = user_value.user_key_id
    ), undef, $key, $self->id());

    my $ret = $row->{user_value};
    return($ret);
}

sub sendVerifyEmail
{
    my $self = shift;
    my %ops = @_;

    my $email = $self->email;
    my $md5 = $self->key("verified");

    my $mail = Email::Simple->create(
        header => [
            To      => $email,
            From    => 'signup@infoservant.com',
            Subject => "Welcome to InfoServant",
        ],
        body => "Thank you for signing up with InfoServant.\nPlease follow the link below to verify your email address:\n\nEmail: $email\nVerification number: $md5\n\nhttp://infoservant.com/verify/$email/$md5\n",
    );

    my $dir = POSIX::strftime("/opt/infoservant.com/emails/%F", localtime(time));
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

    my $verify = $self->key("verified");
    if ("SUCCESS" eq $verify) {
        return(1);
    }
    else {
        return(0);
    }
}

__PACKAGE__->meta->make_immutable;

1;
