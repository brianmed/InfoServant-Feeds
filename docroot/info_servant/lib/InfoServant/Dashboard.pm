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
use XML::Simple qw(:strict);

sub show {
    my $self = shift;

    if (!$self->session->{account_id}) {
        my $url = $self->url_for('/');
        return($self->redirect_to($url));
    }

    my $account = SiteCode::Account->new(id => $self->session->{account_id});
    my $have_feeds = SiteCode::Feeds->haveFeeds(account => $account);
    $self->stash(have_feeds => $have_feeds);

    my $feeds = SiteCode::Feeds->new(account => $account);
    my @feeds = ();
    foreach my $feed (@{ $feeds->feeds() }) {
        my $obj = SiteCode::Feed->new(id => $$feed{id});
        # $self->app->log->debug("title: " . $obj->key("title"));
        push(@feeds, { id => $$feed{id}, name => $obj->key("title") || $$feed{name} });
    }
    @feeds = sort({ $a->{name} cmp $b->{name} } @feeds);

    $self->render(feeds => \@feeds);
}

sub profile {
    my $self = shift;

    if ($self->param("new_feed")) {
        my $new_feed = $self->param("new_feed");

        my $feed = undef;

        eval {
            die("Does not look like a http URI\n") if $new_feed !~ $RE{URI}{HTTP};

            my $account = SiteCode::Account->new(id => $self->session->{account_id});

            if (SiteCode::Feed->exists(name => $new_feed, account => $account)) {
                die("Feed exists already.\n");
            }

            $feed = SiteCode::Feed->addFeed(
                account => $account,
                url => $new_feed,
                route => $self,
            );
        };
        if ($@) {
            my $err = $@;
            if ("Feed exists already.\n" eq $err) {
                $self->stash(errors => "Feed exists already");
            }
            elsif ("Does not look like a http URI\n" eq $err) {
                $self->stash(errors => "Feed may not be properly formatted");
            }
            else {
                $self->app->log->debug("InfoServant::Dashboard::profile::new_feed: $err");
                $self->stash(errors => "Unable to add feed");
            }
        }
        else {
            my $string = $feed->key("title") || $feed->key("url");
            $self->stash(info => "Added: $string");
            $self->stash(reload => 1);
        }
    }
    elsif ($self->param("verify_number")) {
        my $account = SiteCode::Account->new(id => $self->session->{account_id});

        if ($account->verified()) {
            $self->stash(error => "Already verified");
        }
        else {
            my $status = $account->verify($self->param("verify_number"));
            if ($status) {
                if ("ALREADY_VERIFIED" eq $status) {
                    $self->stash(error => "Already verified");
                }
                elsif ("VERIFIED" eq $status) {
                    $self->stash(info => "Sucessfully verified: thank you.");
                }
            }
            else {
                $self->stash(error => "Unable to verify.");
            }
        }
    }
    elsif (ref($self->param("google_import"))) {
        my $filename = "/tmp/google_import.$$.txt";
        my $import = $self->param('google_import');
        $import->move_to($filename);
        my $ref = XMLin($filename, KeyAttr => { outline => 'xmlUrl' }, ForceArray => [ 'body', 'outline' ]);

        my $outline = $ref->{body}[0]{outline};

        my $account = SiteCode::Account->new(id => $self->session->{account_id});
        my $count = 0;
        foreach my $new_feed (sort keys %{ $outline }) {
            if (SiteCode::Feed->exists(name => $new_feed, account => $account)) {
                next;
            }

            SiteCode::Feed->addFeed(
                account => $account,
                url => $new_feed,
                route => $self,
            );
            if ($@) {
                my $err = $@;
                $self->app->log->debug("InfoServant::Dashboard::profile::new_feed: $err");
            }
            else {
                ++$count;
                $self->stash(reload => 1);
            }
        }

        $self->stash(info => "Imported $count feeds.");
    }
}

sub retrieve_feed_entries {
    my $self = shift;

    if (!$self->session->{account_id}) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");

    my $account = SiteCode::Account->new(id => $self->session->{account_id});
    my $feed = SiteCode::Feed->new(id => $feed_nbr, route => $self);
    my $entries = $feed->entries();

    my $data = [];
    foreach my $entry (@{ $entries }) {
        # $self->app->log->debug("title: $$entry{entry}{title}");
        push(@{ $data }, { title => $entry->title(), feed_id => $feed->id(), entry_id => Mojo::Util::url_escape($entry->id()) });
    }

    return($self->render(json => $data));
}

sub retrieve_feed_link {
    my $self = shift;

    if (!$self->session->{account_id}) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");

    my $account = SiteCode::Account->new(id => $self->session->{account_id});
    my $feed = SiteCode::Feed->new(id => $feed_nbr);
    my $link = SiteCode::Feed->latest_link();

    return($self->render(data => $link));
}

sub retrieve_feed_src {
    my $self = shift;

    if (!$self->session->{account_id}) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");
    my $entry_id = $self->param("entry_id");

    my $account = SiteCode::Account->new(id => $self->session->{account_id});
    my $feed = SiteCode::Feed->new(id => $feed_nbr, route => $self);
    my $html = $feed->html(entry_id => $entry_id);
    my $link = $feed->link(entry_id => $entry_id);
    my $title = $feed->title(entry_id => $entry_id);

    $html = sprintf(qq(
            <a href="$link" target=article>$title</a>
            <textarea id="editor1" name="editor1" cols="100" rows="40">
            %s
            </textarea>
    ), Mojo::Util::xml_escape($html));
    # $self->app->log->debug("html: $html");
    return($self->render(text => $html));
}

sub retrieve_html {
    my $self = shift;

    if (!$self->session->{account_id}) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $page = $self->param("page");
    $self->app->log->debug("page: $page");

    if ("profile" eq $page) {
        $self->profile();
    }

    my $account = SiteCode::Account->new(id => $self->session->{account_id});
    $self->stash(account_verified => $account->verified());

    my $have_feeds = SiteCode::Feeds->haveFeeds(account => $account);
    $self->stash(have_feeds => $have_feeds);

    if ($self->session("verify")) {
        $self->stash(verify_number => $self->session("verify"));
        delete($self->session->{verify});
    }

    return($self->render(template => "dashboard/$page", format => "html"));
}

sub retrieve_js {
    my $self = shift;

    if (!$self->session->{account_id}) {
        return($self->render_json(json => { success => 0, error => "Session has expired."}));
    }

    my $page = $self->param("page");
    if ("phone" eq $page) {
        $self->phone();
    }

    return($self->render(template => "dashboard/$page", format => "js"));
}

sub logout {
    my $self = shift;

    my @keys = keys %{ $self->session };

    foreach my $k (@keys) {
        delete($self->session->{$k});
    }

    my $url = $self->url_for('/');
    return($self->redirect_to($url));
}

1;
