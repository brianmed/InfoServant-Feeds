package SiteCode::Feeds;

use SiteCode::Modern;

use Moose;
use namespace::autoclean;

use SiteCode::DBX;
use SiteCode::Feeds;

has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', default => sub { SiteCode::DBX->new() } );
has 'account' => ( isa => 'SiteCode::Account', is => 'ro' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );

sub addFeed {
    my $self = shift;
    my %opt = @_;

    my $account = $opt{account};
    my $url = $opt{url};

    my $feed;

    eval {
        my $dbx = SiteCode::DBX->new();

        $dbx->do("INSERT INTO feed (name) VALUES (?)", undef, $url);

        my $id = $dbx->last_insert_id(undef,undef,undef,undef,{sequence=>'feed_id_seq'});
        $dbx->dbh->commit;

        $self->route->app->log->debug("SiteCode::Feeds::addFeed: $id");
        $feed = SiteCode::Feed->new(id => $id, account => $account);
        $feed->key("xml_url", $url);
        $feed->subscribe();
    };
    if ($@) {
        die($@);
    }

    return($feed);
}

sub haveFeeds {
    my $self = shift;
    my %opt = @_;

    return(SiteCode::DBX->new()->col("SELECT count(id) FROM feedme WHERE account_id = ?", undef, $opt{account}->id()));
}

sub exists {
    my $class = shift;

    my %opt = @_;

    if ($opt{name}) {
        return(SiteCode::DBX->new()->col("SELECT id FROM feed WHERE name = ?", undef, $opt{name}));
    }
    else {
        return 0;
    }
}

sub latest {
    my $self = shift;
    my %opt = @_;

    my $dbx = $self->dbx();

    my $feed = $opt{feed} ? " AND feed.id = ?" : "";
    my @vars = ($self->account()->id());
    push(@vars, $opt{feed}) if $feed;
    my $data = $dbx->array(qq(
        SELECT
            feed.id as feed_id, entry.id as entry_id, entry.issued
        FROM feedme, feed, entry where feedme.account_id = ? 
            and feed.name = entry.feed_name 
            and feedme.feed_id = feed.id
            $feed
        order by entry.issued desc
        LIMIT $opt{limit}
        OFFSET $opt{offset}
    ), undef, @vars);

    return($data);
}

sub feeds {
    my $self = shift;
    my %opt = @_;

    my $dbx = $self->dbx();

    my $feeds = $dbx->array(qq(
        SELECT feed.id, coalesce(feed_value.feed_value, feed.name) as name
        FROM feedme, feed 
            LEFT JOIN feed_key ON (feed_key.feed_id = feed.id AND feed_key.feed_key = 'title') 
            LEFT JOIN feed_value ON (feed_value.feed_key_id = feed_key.id)
        WHERE feedme.account_id = ? and feed.id = feedme.feed_id
        ORDER BY 2
    ), undef, $self->account()->id());

    return($feeds);
}

__PACKAGE__->meta->make_immutable;

1;
