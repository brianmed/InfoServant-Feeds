#! /opt/perl

use Modern::Perl '2013';

use XML::Feed;
use URI;
use URI::file;

my $source = 'http://www.appleinsider.com/appleinsider.rss';
# my $feed = XML::FeedPP->new( $source );
# my $parse = XML::Feed->parse(URI->new($source));
my $parse = XML::Feed->parse("//opt/infoservant.com/data/feed_files/$ARGV[0]");
my $entry;
foreach my $e ( $parse->entries() ) {
    $entry = $e;
    last;
}

print "Title: ", $parse->title(), "\n";
