package SiteCode::Feeds;

use SiteCode::Modern;

use Moose;
use namespace::autoclean;

use SiteCode::DBX;

has 'dbx' => ( isa => 'SiteCode::DBX', is => 'ro', default => sub { SiteCode::DBX->new() } );
has 'account' => ( isa => 'SiteCode::Account', is => 'ro' );

sub haveFeeds {
    my $self = shift;
    my %opt = @_;

    return(SiteCode::DBX->new()->col("SELECT count(id) FROM feed WHERE account_id = ?", undef, $opt{account}->id()));
}

sub latest {
    my $self = shift;
    my %opt = @_;

    my $dbx = $self->dbx();

    my $data = $dbx->array(qq(
        SELECT
            feed.id as feed_id, entry.id as entry_id, entry.issued
        FROM feed, entry where feed.account_id = ? 
            and feed.name = entry.feed_name 
        order by entry.issued desc
        LIMIT $opt{limit}
    ), undef, $self->account()->id());

    return($data);
}

sub feeds {
    my $self = shift;
    my %opt = @_;

    my $dbx = $self->dbx();

    my $feeds = $dbx->array(qq(
        SELECT feed.id, coalesce(feed_value.feed_value, feed.name) as name
        FROM feed 
            LEFT JOIN feed_key ON (feed_key.feed_id = feed.id AND feed_key.feed_key = 'title') 
            LEFT JOIN feed_value ON (feed_value.feed_key_id = feed_key.id)
        WHERE account_id = ?
        ORDER BY 2
    ), undef, $self->account()->id());

    return($feeds);
}

__PACKAGE__->meta->make_immutable;

1;
