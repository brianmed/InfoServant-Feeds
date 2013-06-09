#!/opt/perl

use lib qw(/opt/infoservant.com/docroot/info_servant/lib);

use Modern::Perl;

use autodie;
use Sys::Syslog;
use SiteCode::DBX;

use Getopt::Long;

my %Options = ();
GetOptions(\%Options, "action=s", "account=i", "feed=i");       # will store in $h{length}

if (!$Options{action}) {
    die("Please pass in action\n");
}

if (!$Options{account}) {
    die("Please pass in account\n");
}

if ("delete" eq $Options{action}) {
    if (!$Options{feed}) {
        die("Please pass in feed\n");
    }

    my $dbx = SiteCode::DBX->new();

    my $to_del = $dbx->array(qq(
        SELECT feed.name, feed_key.id as feed_key_id, feed_value.id as feed_value_id
        FROM feed, feed_key, feed_value
        WHERE feed.id = ?
            AND feed_key.feed_id = feed.id
            AND feed_value.feed_key_id = feed_key.id
            AND feed.account_id = ?
    ), undef, $Options{feed}, $Options{account});

    my @feed_vals = ();
    my @feed_keys = ();
    my $name = "";

    foreach my $del (@{ $to_del }) {
        $name = $$del{name};
        push(@feed_vals, $$del{feed_value_id});
        push(@feed_keys, $$del{feed_key_id});
    }

    exit if "" eq $name;

    my $q = SiteCode::DBX->question(scalar @feed_vals);
    $dbx->do("DELETE FROM feed_value WHERE id IN ($q)", undef, @feed_vals);
    $dbx->do("DELETE FROM feed_key WHERE id IN ($q)", undef, @feed_keys);
    $dbx->do("DELETE FROM feed WHERE id IN (?)", undef, $Options{feed});

    openlog("feed_mgmt", 'cons,pid', 'user');
    syslog('info', 'deleting :: %s :: %s :: %s', $$, $name, $Options{feed});
    closelog();
}
elsif ("list" eq $Options{action}) {

    my $dbx = SiteCode::DBX->new();

    my $to_list = $dbx->array(qq(
        SELECT feed.name, feed.id as feed_id, feed_key.id as feed_key_id, feed_value.id as feed_value_id, feed_key, feed_value
        FROM feed, feed_key, feed_value
        WHERE 
            feed_key.feed_id = feed.id
            AND feed_value.feed_key_id = feed_key.id
            AND feed.account_id = ?
    ), undef, $Options{account});

    foreach my $list (@{ $to_list }) {
        print("$$list{name}\t$$list{feed_id}\t$$list{feed_key}\t$$list{feed_value}\n");
    }
}
