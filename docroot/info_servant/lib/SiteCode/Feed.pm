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

has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', default => sub { SiteCode::DBX->new() } );
has 'id' => ( isa => 'Int', is => 'rw' );
has 'feed' => ( isa => 'Email', is => 'rw' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );
has 'data_dir' => ( isa => 'Str', is => 'ro', default => "/opt/infoservant.com/data/feed_files" );

sub addFeed {
    my $self = shift;
    my %opt = @_;

    my $account = $opt{account};
    my $url = $opt{url};

    my $feed;

    eval {
        my $dbx = SiteCode::DBX->new();

        $dbx->do("INSERT INTO feed (account_id, name) VALUES (?, ?)", undef, $account->id(), $url);

        my $id = $dbx->last_insert_id(undef,undef,undef,undef,{sequence=>'feed_id_seq'});
        $feed = SiteCode::Feed->new(id => $id);
        $feed->key("url", $url);

        eval {
            my $parse = XML::Feed->parse(URI->new($url));
            $feed->key("title", $parse->title());
        };
        if ($@) {
            $opt{route}->app->log->debug("addFeed: $@");
        }
    };
    if ($@) {
        die($@);
    }

    return($feed);
}

sub entries {
    my $self = shift;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    if (!defined $parse) {
        return([]);
    }

    return([$parse->entries()]);
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

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    my $entry = undef;
    my $entry_id = Mojo::Util::url_unescape($opt{entry_id});
    foreach my $e ( $parse->entries() ) {
        if ($entry_id eq $e->id()) {
            $entry = $e;
            last;
        }
    }

    return("") if !$entry;
    return(decode_entities($entry->title));
}

sub link {
    my $self = shift;
    my %opt = @_;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    my $entry = undef;
    my $entry_id = Mojo::Util::url_unescape($opt{entry_id});
    foreach my $e ( $parse->entries() ) {
        if ($entry_id eq $e->id()) {
            $entry = $e;
            last;
        }
    }

    return("") if !$entry;
    return(decode_entities($entry->link));
}

sub html {
    my $self = shift;
    my %opt = @_;

    my $url = $self->key("url");

    my $url_dir = Mojo::Util::url_escape($url);
    my $the_dir = $self->data_dir() . "/$url_dir";

    my $parse = XML::Feed->parse("$the_dir/the.feed");

    my $entry = undef;
    my $entry_id = Mojo::Util::url_unescape($opt{entry_id});
    foreach my $e ( $parse->entries() ) {
        if ($entry_id eq $e->id()) {
            $entry = $e;
            last;
        }
    }

    return("") if !$entry;
    return(decode_entities($entry->content->body));
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

sub exists {
    my $class = shift;

    my %opt = @_;

    if ($opt{name}) {
        my $account_id = $opt{account}->id();

        return(SiteCode::DBX->new()->col("SELECT id FROM feed WHERE name = ? and account_id = ?", undef, $opt{name}, $account_id));
    }
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
        }
        else {
            $dbx->do("INSERT INTO feed_key (feed_id, feed_key) VALUES (?, ?)", undef, $self->id(), $key);
            my $feed_key_id = $dbx->last_insert_id(undef,undef,undef,undef,{sequence=>'feed_key_id_seq'});
            $dbx->do("INSERT INTO feed_value (feed_key_id, feed_value) VALUES (?, ?)", undef, $feed_key_id, $value);
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

__PACKAGE__->meta->make_immutable;

1;
