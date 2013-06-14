#!/opt/perl

use lib qw(/opt/infoservant.com/docroot/info_servant/lib);

use Modern::Perl;

use autodie;

use File::Slurp;
use Sys::Syslog;

use SiteCode::DBX;
use XML::Feed;

use Mojo::Util;

use Mojo::UserAgent;

my $data_dir = "/opt/infoservant.com/data/feed_files";
Mojo::Util::spurt($$, "/tmp/feeder.pl.pid");

while (1) {
    my $dbx = SiteCode::DBX->new();

    my $feeds = $dbx->array(qq(
        select distinct feed_value.feed_value as url from feed_key, feed_value where feed_key = 'url' and feed_key.id = feed_key_id
    ));

    foreach my $feed (@{ $feeds }) {
        my $url_dir = Mojo::Util::url_escape($$feed{url});

        my $the_dir = "$data_dir/$url_dir";

        if (!-d $the_dir) {
            mkdir($the_dir);
            Mojo::Util::spurt("0", "$the_dir/last_modified");
        }
        else {
            my @stat = stat($the_dir);
            my $mtime = $stat[9];

            my $diff = time() - $mtime;
            if (900 > $diff) {
                next;
            }
        }

        my $ua = Mojo::UserAgent->new;
        $ua->max_redirects(10);

        openlog("feeder", 'cons,pid', 'user');
        syslog('info', 'ua->head :: %s :: %s', $$, $$feed{url});
        closelog();

        my $tx = $ua->head($$feed{url});
        if (my $res = $tx->success) { 
            my $last_modified = $tx->res->headers->last_modified || "";
            my $prev_modified = Mojo::Util::slurp("$the_dir/last_modified");

            system("/bin/touch", $the_dir);

            if ($last_modified eq $prev_modified) {
                next;
            }

            Mojo::Util::spurt($last_modified, "$the_dir/last_modified");
        }
        else {
            my ($err, $code) = $tx->error;
            my $string =  $code ? "$code response: $err" : "Connection error: $err";

            openlog("feeder", 'cons,pid', 'user');
            syslog('info', "head error(%s) :: %s :: %s", $$feed{url}, $$, $string);
            closelog();

            system("/bin/touch", $the_dir);

            next;
        }

        openlog("feeder", 'cons,pid', 'user');
        syslog('info', 'ua->get :: %s :: %s', $$, $$feed{url});
        closelog();

        $tx = $ua->get($$feed{url});
        if (my $res = $tx->success) { 
            Mojo::Util::spurt($res->body, "$the_dir/the.feed");

            openlog("feeder", 'cons,pid', 'user');
            syslog('info', "spurt(%s) :: %s :: %s", "$the_dir/the.feed", $$, $$feed{url});
            closelog();
        } else {
            my ($err, $code) = $tx->error;
            my $string =  $code ? "$code response: $err" : "Connection error: $err";

            openlog("feeder", 'cons,pid', 'user');
            syslog('info', "get error(%s) :: %s :: %s", $$feed{url}, $$, $string);
            closelog();
        }

        system("/bin/touch", $the_dir);
    }

    sleep(5);
}

1;
