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

package InfoServant::Dashboard;

use Mojo::Base 'Mojolicious::Controller';

use SiteCode::Account;
use SiteCode::Feed;
use SiteCode::Feeds;
use SiteCode::DBX;

use Mojo::Util;

use HTML::Entities;
use Regexp::Common qw(URI);
use XML::OPML::LibXML;
use File::Temp;
use Time::Local;
use LWP::UserAgent;
use JSON;
use HTTP::Request::Common;

sub dateify {
    if ($_[0] =~ m/^(\d+)-(\d+)-(\d+)\s+(\d+).(\d+)/) {
        my $dt = DateTime->new(
            year => $1,
            month => $2,
            day => $3,
            hour => $4,
            minute => $5,
        );

        return($dt);
    }
    else {
        return(DateTime->now());
    }
}

sub show {
    my $self = shift;

    $self->session(offset => $self->param("offset")) if defined $self->param("offset");

    my $account = undef;

    eval {
        $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);
    };
    if ($@) {
        $self->app->log->debug("InfoServant::Dashboard::show: $@");
        $self->session(expires => 1);

        my $url = $self->url_for('/');
        return($self->redirect_to($url));
    }

    my $stripe_id = $account->key("stripe_id");

    $self->stash(account_verified => $account->verified());
    $self->stash(account_purchased => defined $stripe_id);

    unless ($stripe_id) {
        my $count = SiteCode::DBX->new()->col("select count(entry_read.id) as count from entry_read, feedme where feedme_id = feedme.id and account_id = ?", undef, $account->id);

        if (150 < $count) {
            $self->stash(upgrade_message => 1);
            return($self->render);
        }
        else {
            $self->stash(articles_left => (150 - $count));
        }
    }

    my $have_feeds = SiteCode::Feeds->haveFeeds(account => $account);
    $self->stash(have_feeds => $have_feeds);

    # If the user selects all feeds
    if ($self->param("feed")) {
        if (-1 == $self->param("feed")) {
            delete $self->session->{cur_feed};
        }
        else {
            $self->session(cur_feed => $self->param("feed"));
       }
    }
    my @entries = ();
    my $feeds = SiteCode::Feeds->new(account => $account);
    my $limit = 30; # $stripe_id ? 30 : 15;
    my $offset = $self->session("offset") ? $self->session("offset") : 0;
    # $offset = 0 if !$stripe_id;

    foreach my $l (@{ $feeds->latest(limit => $limit, offset => $offset, feed => $self->session("cur_feed")) }) {
        my $obj = SiteCode::Feed->new(id => $$l{feed_id}, route => $self);
        my $entry = $obj->entry($$l{entry_id}, $account->id());

        my $dt = dateify($$entry{inserted});
        my $date = $dt->strftime("%A, %B, %e, %Y");
        my $time = $dt->strftime("%H:%M");
        my $the_m = $dt->strftime("%p");

        push(@entries, { id => $$entry{id}, date => $date, time => $time, the_m => $the_m, feed_title => $$entry{feed_title}, entry_id => $$l{entry_id}, issued => $$entry{issued}, title => $$entry{title}, feed_id => $obj->id() });
    }
    if (scalar @entries) {
        $self->stash(have_entries => 1);
    }
    elsif ($self->session("cur_feed")) {
        my $obj = SiteCode::Feed->new(id => $self->session("cur_feed"), route => $self);
        my $last_check = $obj->key("last_check");
        my $last_modified = $obj->key("last_modified");
        $last_check = $last_check ? scalar(localtime($last_check)) : "Unknown";
        $last_modified = $last_modified ? $last_modified : "Unknown";
        $self->stash(last_check => $last_check);
        $self->stash(last_modified => $last_modified);
    }

    my @feeds = ();
    foreach my $f (@{ $feeds->feeds() }) {
        push(@feeds, { count => $$f{count}, id => $$f{id}, name => $$f{name}});
    }
    if (@feeds) {
        $self->stash(have_feeds => 1);
    }

    if ($self->session("cur_feed")) {
        my $feed = SiteCode::Feed->new(id => $self->session("cur_feed"), route => $self);
        my $feed_title = $feed->key("title") || $feed->key("xml_url");
        $self->stash(cur_title => $feed_title);
    }

    $self->render(entries => \@entries, feeds => \@feeds);
}

sub details {
    my $self = shift;

    my $entry_id = $self->param("entry_id");
    my $feed_nbr = $self->param("feed_id");
    my $offset = $self->session("offset");

    my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

    eval {
        my $feed = SiteCode::Feed->new(id => $feed_nbr, route => $self, account => $account);
        my $html = $feed->html(entry_id => $entry_id, account_id => $account->id);
        my $link = $feed->link(entry_id => $entry_id, account_id => $account->id);
        my $title = $feed->title(entry_id => $entry_id, account_id => $account->id);
        my $feed_title = $feed->key("title") || $feed->key("xml_url");

        $feed->mark_read(entry_id => $entry_id, feed_id => $feed_nbr);

        $self->stash(offset => $offset, feed_title => $feed_title, html => $html, link => $link, title => $title, entry_id => $entry_id, feed_id => $feed_nbr);
    };
    if ($@) {
        $self->app->log->debug("Error: details: $@");
        my $html = qq(
            The following url didn't work:<br>
            http://infoservant.com/details?entry_id=$entry_id&feed_id=$feed_nbr
        );
        my $link = "http://infoservant.com/dashboard";
        my $title = "Oops";
        $self->stash(offset => $offset, feed_title => "Error: $feed_nbr", html => $html, link => $link, title => $title, entry_id => $entry_id, feed_id => $feed_nbr);
    }

    return($self->render());
}

sub verify {
    my $self = shift;

    my $verify = $self->param("verify") || $self->session("verify");

    unless ($verify) {
        $self->stash(error => "No verification number.");
        return($self->render("dashboard/dialog"));
    }

    my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

    if ($account->verified()) {
        $self->stash(error => "Already verified.");
        delete $self->session->{verify};
    }
    else {
        my $status = $account->verify($verify);
        if ($status) {
            if ("ALREADY_VERIFIED" eq $status) {
                $self->stash(error => "Already verified.");
                delete $self->session->{verify};
            }
            elsif ("VERIFIED" eq $status) {
                $self->stash(success => "Successfully verified.");
                delete $self->session->{verify};
            }
        }
        else {
            $self->stash(error => "Unable to verify.");
        }
    }

    $self->render("dashboard/dialog");
}

sub cancel {
    my $self = shift;

    my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);
    $self->stash(account_purchased => defined $account->key("stripe_id"));

    if ("GET" eq $self->req->method) {
        return($self->render());
    }

    unless ($self->param("verify")) {
        $self->stash(error => "Please enter CANCEL below.");
        return($self->render());
    }

    if ("CANCEL" ne $self->param("verify")) {
        $self->stash(error => "CANCEL not typed exactly.");
        return($self->render());
    }

    my $stripe_id = $account->key("stripe_id");

    my $req = &HTTP::Request::Common::DELETE(
        "https://api.stripe.com/v1/customers/$stripe_id",
    );

    my $site_config = SiteCode::Site->config();
    my $ver = $$site_config{stripe_version};
    my $key = "stripe_key_$ver";
    my $api_key = $$site_config{$key};

    my $ua = LWP::UserAgent->new();
    $ua->credentials("api.stripe.com:443", "Stripe", $api_key, "");
    my $res = $ua->request($req);
    if ($res->is_success()) {
        $account->key("stripe_id", undef);

        $self->stash(success => "Subscription cancelled.");
    }
    else {
        my $ret = JSON::from_json($res->content());
        $self->stash(error => $ret->{error}{message});

        return($self->render());
    }

    $self->render();
}

sub purchase {
    my $self = shift;

    my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

    if ("GET" eq $self->req->method) {
        $self->stash(info => "Only \$1.50 a month!<br>Thirty day trial.");
        return($self->render());
    }

    my %map = (
        name => "Name on Card",
        number => "Credit Card Number",
        exp_month => "Expiration Month",
        exp_year => "Expiration Year",
        cvc => "Expiration Year",
    );
    foreach my $param (qw(name number exp_month exp_year cvc)) {
        my $human = $map{$param};
        unless ($self->param($param)) {
            $self->stash(error => "$human not found.");
            return($self->render());
        }
    }

    my $name = $self->param("name");
    my $number = $self->param("number");
    my $exp_month = $self->param("exp_month");
    my $exp_year = $self->param("exp_year");
    my $cvc = $self->param("cvc");

    my $site_config = SiteCode::Site->config();
    my $ver = $$site_config{stripe_version};
    my $key = "stripe_key_$ver";
    my $api_key = $$site_config{$key};

    my $req = &HTTP::Request::Common::POST(
        'https://api.stripe.com/v1/customers',
        Content => 
        [ 
            description => $self->session("account_id"),
            "card[number]" => $number,
            "card[exp_month]" => $exp_month,
            "card[exp_year]" => $exp_year,
            "card[cvc]" => $cvc,
            "card[name]" => $name,
            "email" => $account->email,
            plan => $$site_config{stripe_plan},
        ] 
    );

    my $ua = LWP::UserAgent->new();
    $ua->credentials("api.stripe.com:443", "Stripe", $api_key, "");
    my $res = $ua->request($req);

    my $ret = JSON::from_json($res->content());

    $self->app->log->debug("InfoServant::Dashboard::purchase: " . $self->dumper($ret));

    if ($res->is_success()) {
        my $id = $ret->{id};

        $account->key("stripe_id", $id);
        $self->stash(account_purchased => defined $account->key("stripe_id"));
        $self->stash(success => "Purchased plan.  Thanks!");
    }
    else {
        $self->stash(error => $ret->{error}{message});
    }

    $self->render();
}

sub mark_read {
    my $self = shift;

    my $entry_id = $self->param("entry_id");
    my $feed_id = $self->param("feed_id");

    my $link = "";

    eval {
        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

        my $feed = SiteCode::Feed->new(id => $feed_id, account => $account, route => $self);
        $feed->mark_read(entry_id => $entry_id, feed_id => $feed_id);
        $link = $feed->link(entry_id => $entry_id, account_id => $account->id);
        
    };
    if ($@) {
        my $err = $@;
        $self->app->log->debug("InfoServant::Dashboard::mark_read: $err");
        $self->stash(error => "Unable to mark entry read.");
    }

    $self->render(json => { link => $link });
}

sub unsubscribe {
    my $self = shift;

    my $cur_feed = $self->session("cur_feed");

    unless ($cur_feed) {
        $self->stash(error => "No feed given.");
        return($self->render("dashboard/dialog"));
    }

    my $feed = undef;

    eval {
        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

        SiteCode::Feed->new(id => $cur_feed, account => $account, route => $self)->unsubscribe;
    };
    if ($@) {
        my $err = $@;
        $self->app->log->debug("InfoServant::Dashboard::new_feed: $err");
        $self->stash(error => "Unable to unsubscribe feed.");
    }
    else {
        $self->stash(success => "Unsubscribed from feed.");
        delete $self->session->{cur_feed};
    }

    $self->render("dashboard/dialog");
}

sub new_feed {
    my $self = shift;

    my $new_feed = $self->param("new_feed");

    unless ($new_feed) {
        $self->stash(error => "No feed given.");
        return($self->render("dashboard/dialog"));
    }

    my $feed = undef;

    eval {
        die("Does not look like a http URI\n") if $new_feed !~ $RE{URI}{HTTP};

        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

        my $exists = SiteCode::Feeds->new(account => $account, route => $self)->exists(name => $new_feed);

        if ($exists) {
            $feed = SiteCode::Feed->new(id => $exists, route => $self, account => $account);
            $feed->subscribe;
        }
        else {
            $feed = SiteCode::Feeds->new(route => $self, account => $account)->addFeed(
                url => $new_feed,
            );
        }
    };
    if ($@) {
        my $err = $@;
        $self->app->log->debug("InfoServant::Dashboard::new_feed: $err");
        if ("Feed exists already.\n" eq $err) {
            $self->stash(error => "Feed exists already");
        }
        elsif ("Does not look like a http URI\n" eq $err) {
            $self->stash(error => "Feed may not be properly formatted");
        }
        else {
            $self->stash(error => "Unable to add feed");
        }
    }
    else {
        my $string = $feed->key("title") || $feed->key("xml_url");
        $self->stash(success => "Added: $string");
    }

    $self->render("dashboard/dialog", title => "Add");
}

sub opml_file {
    my $self = shift;

    my $tmp = File::Temp->new( TEMPLATE => "opml_import.$$.XXXXXX", UNLINK => 0, SUFFIX => '.opml', TMPDIR => 1 );
    my $filename = $tmp->filename;
    my $import = $self->param('opml_file');
    if ($import) {
        $import->move_to($filename);
    }

    $self->app->log->debug("opml_import: $filename");

    unless (-s $filename) {
        $self->stash(error => "No file detected.");

        return($self->render("dashboard/dialog"));
    }

    my $count = 0;
    my $skipped = 0;
    my $already = 0;
    my $processed = 0;

    my $process = sub {
        my $outline = shift;

        state $tag;

        if ($outline->is_container) {
            $tag = $outline->text;
        }
        
        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

        my $xml_url = $outline->xml_url;
        my $html_url = $outline->html_url;

        return unless $xml_url;
        
        my $exists;
        my $subscribed;

        eval {
            $exists = SiteCode::Feeds->new(account => $account, route => $self)->exists(name => $xml_url);
            my $f = $exists ? SiteCode::Feed->new(name => $xml_url, account => $account, route => $self)->subscribed : 0;
        };
        if ($@) {
            $self->app->log->debug("Error: opml_import:process: $@");
            return;
        }

        if ($exists && $subscribed) {
            ++$already;
            return;
        }

        my $feed;
        eval {
            if ($exists) {
                $feed = SiteCode::Feed->new(name => $xml_url, route => $self, account => $account);
            }
            else {
                $feed = SiteCode::Feeds->new(account => $account, route => $self)->addFeed(
                    url => $xml_url,
                );
            }
            if ($subscribed) {
                ++$already;
                ++$processed;
            }
            else {
                $feed->subscribe;
            }
        };
        if ($@) {
            my $err = $@;
            $self->app->log->debug("Error: opml_import:add: $@");
            ++$skipped;
        }
        else {
            $feed->key("tag", $tag) if $tag;
            ++$count;
            ++$processed;
        }
    };

    eval {
        my $parser = XML::OPML::LibXML->new;
        my $doc    = $parser->parse_file($filename);

        $doc->walkdown($process);

        $self->stash(success => "Processed $processed feeds.");
        $self->stash(info => "The import will happen in the background.") if $processed;
    };
    if ($@) {
        $self->app->log->debug("Error: opml_import:process: $@");
        $self->stash(error => "Error processing file.");
    }

    $self->render("dashboard/dialog");
}

sub websocket {
    my $self = shift;
    my $w;
    
    return if $self->session("cur_feed");
    
    # Opened
    $self->app->log->debug('WebSocket opened.');
    
    # Increase inactivity timeout for connection a bit
    my $id = Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
    
    # Incoming message
    $self->on(message => sub {
        my ($self, $msg) = @_;

        # Do we need to do this?
        if ("Ping" eq $msg) {
            return;
        }

        return;

        # $self->send("echo: $msg");
    });
    
    # Closed
    $self->on(finish => sub {
        my ($self, $code, $reason) = @_;

        Mojo::IOLoop->remove($w);

        $self->app->log->debug("WebSocket closed with status $code.");
    });

    $w = Mojo::IOLoop->recurring(60 => sub{
        state $whence = time();
        state $count = 0;

        # $self->app->log->debug("Recurring: $whence: $count");

        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);
        my $feeds = SiteCode::Feeds->new(account => $account);

        my @entries = ();

        foreach my $l (@{ $feeds->latest(whence => $whence, limit => 15, offset => 0 )}) {
            my $obj = SiteCode::Feed->new(id => $$l{feed_id}, route => $self);
            my $entry = $obj->entry($$l{entry_id}, $account->id());

            my $dt = dateify($$entry{inserted});
            my $date = $dt->strftime("%A, %B, %e, %Y");
            my $time = $dt->strftime("%H:%M");
            my $the_m = $dt->strftime("%p");

            my $feed_title = Mojo::Util::xml_escape($$entry{feed_title});
            my $title = Mojo::Util::xml_escape($$entry{title});

            push(@entries, { id => $$entry{id}, date => $date, time => $time, the_m => $the_m, feed_title => $feed_title, entry_id => $$l{entry_id}, issued => $$entry{issued}, title => $title, feed_id => $obj->id() });
        }

        if (scalar @entries) {
            $whence = time();
        }

        ++$count;
        $self->send({ json => \@entries });
    });
}

sub logout {
    my $self = shift;

    $self->session(expires => 1);

    my $url = $self->url_for('/');
    return($self->redirect_to($url));
}

1;
