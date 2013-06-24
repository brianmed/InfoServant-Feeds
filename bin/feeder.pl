#!/opt/perl

use lib qw(/opt/infoservant.com/docroot/info_servant/lib);

use SiteCode::Modern;

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
        select distinct name as url from feed
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

        info('ua->head :: %s', $$feed{url});

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

            info("head error(%s) :: %s", $$feed{url}, $string);

            system("/bin/touch", $the_dir);

            next;
        }

        info('ua->get :: %s', $$feed{url});

        $tx = $ua->get($$feed{url});
        if (my $res = $tx->success) { 
            Mojo::Util::spurt($res->body, "$the_dir/the.feed");

            info("spurt(%s) :: %s", "$the_dir/the.feed", $$feed{url});
        } else {
            my ($err, $code) = $tx->error;
            my $string =  $code ? "$code response: $err" : "Connection error: $err";

            info("get error(%s) :: %s", $$feed{url}, $string);
        }

        system("/bin/touch", $the_dir);

        my $parse;
        eval {
            $parse = XML::Feed->parse("$the_dir/the.feed");
        };
        if ($@) {
            info("parse error(%s) :: %s", $$feed{url}, $@);
        }
        my $entries = $parse ? [$parse->entries()] : [];

        if (@{ $entries}) {
            info("DELETE FROM entry (%s) :: %s", $$feed{url}, scalar(@{ $entries }));

            eval {
                $dbx->do("DELETE FROM entry WHERE feed_name = ?", undef, $$feed{url});
            };
            if ($@) {
                info("DELETE FROM entry error(%s) :: %s", $$feed{url}, $@);
            }
            else {
                foreach my $entry (@{ $entries }) {
                    eval {
                        # Why there twice?
                        my $exists = $dbx->col("SELECT id FROM entry WHERE feed_name = ? and entry_id = ?", undef, $$feed{url}, $entry->id());
                        $dbx->do(
                            "INSERT INTO entry (feed_name, feed_title, issued, title, entry_id, link, html) VALUES (?, ?, ?, ?, ?, ?, ?)", 
                            undef, 
                            $$feed{url},
                            $parse->title(),
                            $entry->issued() || "CURRENT_TIMESTAMP", 
                            $entry->title(), 
                            $entry->id(), 
                            $entry->link(), 
                            substr($entry->content->body(), 0, 65535),
                        ) unless $exists;
                    };
                    if ($@) {
                        my $err = $@;
                        info("INSERT INTO entry error(%s) :: %s", $$feed{url}, $err);
                    }
                }

                info("INSERT INTO entry :: %s :: %s", $$feed{url}, scalar(@{ $entries }));
            }
        }
    }

    info("COMPLETE full scan");

    mem_usage();

    sleep(45);
}

sub info {
    openlog("feeder", 'cons,pid', 'user');
    syslog('info', @_);
    closelog();
}

sub mem_usage {
    my $file = "/proc/$$/statm";
    my $text = Mojo::Util::slurp($file);

    my @fields = split(/\s+/, $text);

    my $rss_pages = $fields[1];
    if (18_000 < $rss_pages) {
        info('exiting :: %s ', $rss_pages);

        exit 0;
    }
}
1;
