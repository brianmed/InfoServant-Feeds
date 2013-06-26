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

package SiteCode::Feed;

use SiteCode::Modern;

use Moose;
use namespace::autoclean;

use SiteCode::DBX;

use XML::Feed;
use HTML::Entities;
use Mojo::Util;

has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', default => sub { SiteCode::DBX->new() } );
has 'account' => ( isa => 'SiteCode::Account', is => 'ro' );
has 'id' => ( isa => 'Int', is => 'rw' );
has 'name' => ( isa => 'Str', is => 'rw' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );
has 'data_dir' => ( isa => 'Str', is => 'ro', default => "/opt/infoservant.com/data/feed_files" );

sub subscribe {
    my $self = shift;

    my $dbx = SiteCode::DBX->new();

    unless ($self->subscribed) {
        $dbx->do("INSERT INTO feedme (feed_id, account_id) VALUES (?, ?)", undef, $self->id, $self->account->id);
        $dbx->dbh->commit;
    }
}

sub subscribed {
    my $self = shift;

    my $dbx = SiteCode::DBX->new();

    my $id = $dbx->col("SELECT id FROM feedme WHERE feed_id = ? and account_id = ?", undef, $self->id, $self->account->id);
}

sub entry {
    my $self = shift;
    my $entry_id = shift;
    my $account_id = shift;

    my $data = $self->dbx()->row(qq(
        SELECT entry.*
        FROM feedme, feed, entry where feedme.account_id = ? 
            and feed.name = entry.feed_name 
            and entry.id = ?
            and feedme.feed_id = feed.id
    ), undef, $account_id, $entry_id);
}

sub entries {
    my $self = shift;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    unless (-f "$the_dir/the.feed") {
        return([]);
    }

    # Ode, to the SQL
    my $parse;
    eval {
        $parse = XML::Feed->parse("$the_dir/the.feed");
    };
    if ($@) {
        $self->route->app->log->debug("entries: $the_dir/the.feed: $@");
        return([]);
    }
    $parse ? return([$parse->entries()]) : return([]);
}

sub latest_link {
    my $self = shift;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    # print "Title: ", $feed->title(), "\n";
    # print "Date: ", $feed->pubDate(), "\n";

    my $entry = undef;
    foreach my $e ( $parse->entries() ) {
        $entry = $e;
        last;

        # print "URL: ", $item->link(), "\n";
        # print "Title: ", $item->title(), "\n";
    }

    return($entry->{entry}{link});
}

sub title {
    my $self = shift;
    my %opt = @_;
    my $entry_id = $opt{entry_id};
    my $account_id = $opt{account_id};

    my $data = $self->dbx()->row(qq(
        SELECT entry.title
        FROM feedme, feed, entry where feedme.account_id = ? 
            and feed.name = entry.feed_name 
            and entry.id = ?
            and feedme.feed_id = feed.id
    ), undef, $account_id, $entry_id);

    return("") if !$data;
    return(decode_entities($$data{title}));
}

sub link {
    my $self = shift;
    my %opt = @_;
    my $entry_id = $opt{entry_id};
    my $account_id = $opt{account_id};

    my $data = $self->dbx()->row(qq(
        SELECT entry.link
        FROM feedme, feed, entry where feedme.account_id = ? 
            and feed.name = entry.feed_name 
            and entry.id = ?
            and feedme.feed_id = feed.id
    ), undef, $account_id, $entry_id);

    return("") if !$data;
    return(decode_entities($$data{link}));
}

sub html {
    my $self = shift;
    my %opt = @_;
    my $entry_id = $opt{entry_id};
    my $account_id = $opt{account_id};

    my $html_file = "/opt/infoservant.com/data/html_files/" . $self->id . "/$entry_id.html";

    return(Mojo::Util::slurp($html_file));
}

sub latest_html {
    my $self = shift;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    my $entry = undef;
    foreach my $e ( $parse->entries() ) {
        $entry = $e;
        last;

        # print "URL: ", $item->link(), "\n";
        # print "Title: ", $item->title(), "\n";
    }

    return($entry->{entry}{description});
}

sub key {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    my $dbx = SiteCode::DBX->new();

    if ($value) {
        my $defined = $self->key($key);

        if ($defined) {
            my $id = $dbx->col("SELECT id FROM feed_key WHERE feed_id = ? AND feed_key = ?", undef, $self->id(), $key);
            $dbx->do("UPDATE feed_value SET feed_value = ? WHERE feed_key_id = ?", undef, $value, $id);
            $dbx->dbh->commit;
        }
        else {
            $dbx->do("INSERT INTO feed_key (feed_id, feed_key) VALUES (?, ?)", undef, $self->id(), $key);
            my $feed_key_id = $dbx->last_insert_id(undef,undef,undef,undef,{sequence=>'feed_key_id_seq'});
            $dbx->do("INSERT INTO feed_value (feed_key_id, feed_value) VALUES (?, ?)", undef, $feed_key_id, $value);
            $dbx->dbh->commit;
        }
    }

    my $row = $dbx->row(qq(
        SELECT 
            feed_key, feed_value 
        FROM 
            feed_key, feed_value 
        WHERE feed_key = ? 
            AND feed_id = ?
            AND feed_key_id = feed_key.id
    ), undef, $key, $self->id());

    my $ret = $row->{feed_value};
    return($ret);
}

sub BUILD {
    my $self = shift;

    eval {
        if ($self->name) {
            unless ($self->id) {
                $self->id($self->dbx()->col("SELECT id FROM feed WHERE name = ?", undef, $self->name));
            }
        }
    };
    if ($@) {
        die("Error SiteCode::Feed::BUILD: $@.\n");
    }
}

__PACKAGE__->meta->make_immutable;

1;
