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

sub show {
    my $self = shift;

    if (!$self->session("account_id")) {
        my $url = $self->url_for('/');
        return($self->redirect_to($url));
    }

    my $account = SiteCode::Account->new(id => $self->session("account_id"));

    my @entries = ();
    my $feeds = SiteCode::Feeds->new(account => $account);
    foreach my $l (@{ $feeds->latest(limit => 30, offset => $self->param("offset") || 0) }) {
        my $obj = SiteCode::Feed->new(id => $$l{feed_id}, route => $self);
        my $entry = $obj->entry($$l{entry_id}, $account->id());

        push(@entries, { entry_id => $$l{entry_id}, issued => $$entry{issued}, title => $$entry{title}, feed_id => $obj->id() });
    }
    if (@entries) {
        $self->stash(have_entries => 1);
    }

    my @feeds = ();
    foreach my $f (@{ $feeds->feeds() }) {
        push(@feeds, { id => $$f{id}, name => $$f{name}});
    }
    if (@feeds) {
        $self->stash(have_feeds => 1);
    }

    $self->stash(offset => $self->param("offset")) if $self->param("offset");

    $self->render(entries => \@entries, feeds => \@feeds);
}

sub verify {
    my $self = shift;

    if (!$self->session("account_id")) {
        my $url = $self->url_for('/');
        return($self->redirect_to($url));
    }

    my $verify = $self->param("verify") || $self->session("verify");

    unless ($verify) {
        $self->stash(error => "No verification number.");
        $self->render("dashboard/dialog");
    }

    my $account = SiteCode::Account->new(id => $self->session("account_id"));

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
                $self->stash(success => "Sucessfully verified.");
                delete $self->session->{verify};
            }
        }
        else {
            $self->stash(error => "Unable to verify.");
        }
    }

    $self->render("dashboard/dialog");
}

sub profile {
    my $self = shift;

    if (defined $self->param("new_feed")) {
        my $new_feed = $self->param("new_feed");

        my $feed = undef;

        eval {
            die("Does not look like a http URI\n") if $new_feed !~ $RE{URI}{HTTP};

            my $account = SiteCode::Account->new(id => $self->session("account_id"));

            my $exists = SiteCode::Feeds->new->exists(name => $new_feed, account => $account);
            my $subscribed = $exists ? SiteCode::Feed->new(name => $new_feed, account => $account, route => $self)->subscribed : 0;

            if ($exists && $subscribed) {
                die("Feed exists already.\n");
            }

            $feed = SiteCode::Feeds->new->addFeed(
                account => $account,
                xml_uRl => $new_feed,
                route => $self,
            );
        };
        if ($@) {
            my $err = $@;
            $self->app->log->debug("InfoServant::Dashboard::profile::new_feed: $err");
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
            my $string = $feed->key("title") || $feed->key("url");
            $self->stash(info => "Added: $string");
            $self->stash(reload => 1);
        }
    }
    elsif ($self->param("verify_number")) {
        my $account = SiteCode::Account->new(id => $self->session("account_id"), route => $self);

        if ($account->verified()) {
            $self->stash(error => "Already verified");
        }
        else {
            my $status = $account->verify($self->param("verify_number"));
            if ($status) {
                if ("ALREADY_VERIFIED" eq $status) {
                    $self->stash(error => "Already verified.");
                }
                elsif ("VERIFIED" eq $status) {
                    $self->stash(info => "Sucessfully verified.");
                    delete $self->session->{verify};
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

        unless (-s $filename) {
            $self->stash(error => "No file detected.");

            return;
        }

        my $count = 0;
        my $skipped = 0;
        my $already = 0;

        my $process = sub {
            my $outline = shift;

            state $tag;

            if ($outline->is_container) {
                $tag = $outline->text;
            }
            
            my $account = SiteCode::Account->new(id => $self->session("account_id"));

            my $xml_url = $outline->xml_url;
            my $html_url = $outline->html_url;

            return unless $xml_url;
            
            my $exists;
            my $subscribed;

            eval {
                $exists = SiteCode::Feeds->new->exists(name => $xml_url, account => $account);
                my $f = $exists ? SiteCode::Feed->new(name => $xml_url, account => $account, route => $self)->subscribed : 0;
            };
            if ($@) {
                $self->app->log->debug("Error: google_import:process: $@");
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
                    $feed = SiteCode::Feeds->new->addFeed(
                        account => $account,
                        url => $xml_url,
                        html_url => $html_url,
                        route => $self,
                    );
                }
                if ($subscribed) {
                    ++$already;
                }
                else {
                    $feed->subscribe;
                }
            };
            if ($@) {
                my $err = $@;
                $self->app->log->debug("Error: google_import:add: $@");
                ++$skipped;
            }
            else {
                $feed->key("tag", $tag) if $tag;
                ++$count;
            }
        };

        eval {
            my $parser = XML::OPML::LibXML->new;
            my $doc    = $parser->parse_file($filename);

            $doc->walkdown($process);

            my $msg = "Subcribed to $count feeds.";
            $msg .= "<br>There were $already feeds already subscribed." if $already;
            $msg .= "<br>There were $skipped feeds skipped." if $skipped;
            $self->stash(success => $msg);
            $self->stash(info => "The import will happen in the background.  Please give us 5 minutes.");
        };
        if ($@) {
            $self->stash(error => "Error processing file.");
        }
    }
}

sub retrieve_feed_entries {
    my $self = shift;

    if (!$self->session("account_id")) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");

    my $account = SiteCode::Account->new(id => $self->session("account_id"));
    my $feed = SiteCode::Feed->new(id => $feed_nbr, route => $self, account => $account);
    my $entries = $feed->entries();

    my $data = [];
    foreach my $entry (@{ $entries }) {
        # $self->app->log->debug("title: $$entry{entry}{title}");
        push(@{ $data }, { title => $entry->{title}, feed_id => $feed->id(), entry_id => Mojo::Util::url_escape($entry->{entry_id}) });
    }

    return($self->render(json => $data));
}

sub retrieve_feed_link {
    my $self = shift;

    if (!$self->session("account_id")) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");

    my $account = SiteCode::Account->new(id => $self->session("account_id"));
    my $feed = SiteCode::Feed->new(id => $feed_nbr);
    my $link = SiteCode::Feed->latest_link();

    return($self->render(data => $link));
}

sub retrieve_feed_src {
    my $self = shift;

    if (!$self->session("account_id")) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $feed_nbr = $self->param("feed_nbr");
    my $entry_id = $self->param("entry_id");

    my $account = SiteCode::Account->new(id => $self->session("account_id"));
    my $feed = SiteCode::Feed->new(id => $feed_nbr, route => $self);
    my $html = $feed->html(entry_id => $entry_id, account_id => $account->id);
    my $link = $feed->link(entry_id => $entry_id, account_id => $account->id);
    my $title = $feed->title(entry_id => $entry_id, account_id => $account->id);

    if ($self->is_mobile) {
        $html = sprintf(qq(
                <div id=content>
                <br>
                <a href="$link" target=article><button class="btn btn-primary">Site</button></a>
                <button class="btn btn-primary" onClick="\$('#content').remove();">Close</button>
                <hr>
                <p>
                %s
                </p>
                </div>
        ), $html);
    }
    else {
        $html = sprintf(qq(
                <a href="$link" target=article><button class="btn btn-primary">Site</button></a>
                <button class="btn btn-primary" onClick="\$('#htmlBody').remove();">Close</button>
                <textarea id="editor1" name="editor1" cols="100" rows="40">
                %s
                </textarea>
        ), Mojo::Util::xml_escape($html));
    }
    # $self->app->log->debug("html: $html");
    return($self->render(text => $html));
}

sub retrieve_html {
    my $self = shift;

    if (!$self->session("account_id")) {
        return($self->render(text => "Session has expired.  <a href=http://infoservant.com/login>Login</a>."));
    }

    my $page = $self->param("page");
    $self->app->log->debug("page: $page");

    if ("profile" eq $page) {
        $self->profile();
    }

    my $account = SiteCode::Account->new(id => $self->session("account_id"));
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

    if (!$self->session("account_id")) {
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

    $self->session(expires => 1);

    my $url = $self->url_for('/');
    return($self->redirect_to($url));
}

1;
