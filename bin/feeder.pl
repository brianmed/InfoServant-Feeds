#!/opt/perl

use lib qw(/opt/infoservant.com/docroot/info_servant/lib);

use SiteCode::Modern;

use autodie;

use File::Slurp;
use File::Path;
use Sys::Syslog;

use SiteCode::DBX;
use XML::Feed;

use Mojo::Util;

use Mojo::UserAgent;

use SiteCode::Feed;
use SiteCode::Feeds;
use DateTime;

my $data_dir = "/opt/infoservant.com/data/feed_files";
my $html_dir = "/opt/infoservant.com/data/html_files";
Mojo::Util::spurt($$, "/tmp/feeder.pl.pid");

while (1) {
    my $dbx = SiteCode::DBX->new();

    my $feeds = $dbx->array(qq(
        select id, name as url from feed
    ));

    foreach my $feed (@{ $feeds }) {
        eval {
            $dbx->do("SELECT id FROM feed WHERE id = ? FOR UPDATE NOWAIT", undef, $$feed{id});
        };
        if ($@) {
            next;
        }

        my $url_dir = Mojo::Util::url_escape($$feed{url});

        my $the_dir = "$data_dir/$url_dir";

        my $obj = SiteCode::Feed->new(id => $$feed{id});

        if (!-d $the_dir) {
            mkdir($the_dir);
        }

        my $last_check = $obj->key("last_check") || 0;
        my $diff = time() - $last_check;
        if (900 > $diff) {
            $dbx->dbh->rollback();
            next;
        }
        $obj->key("last_check", time());
        $dbx->dbh->commit;

        my $ua = Mojo::UserAgent->new;
        $ua->max_redirects(10);

        info('ua->head :: %s', $$feed{url});

        my $tx = $ua->head($$feed{url});
        if (my $res = $tx->success) { 
            my $last_modified = $tx->res->headers->last_modified || "";
            my $prev_modified = $obj->key("last_modified") || "";

            if ($last_modified eq $prev_modified) {
                next;
            }

            $obj->key("last_modified", $last_modified);
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
            $obj->key("title", $parse->title());
            $obj->key("base", $parse->base());
            $obj->key("link", $parse->link());
        };
        if ($@) {
            info("parse error(%s) :: %s", $$feed{url}, $@);
        }
        my $entries = $parse ? [$parse->entries()] : [];

        my $feed_path = "$html_dir/$$feed{id}";
        if (!-d $feed_path) {
            mkdir($feed_path);
        }
        if (@{ $entries}) {
                foreach my $entry (@{ $entries }) {
                    eval {
                        my $exists = $dbx->col("SELECT id FROM entry WHERE feed_name = ? and entry_id = ?", undef, $$feed{url}, $entry->id());
                        unless ($exists) {
                            $dbx->do(
                                "INSERT INTO entry (feed_name, feed_title, issued, title, entry_id, link) VALUES (?, ?, ?, ?, ?, ?)", 
                                undef, 
                                $$feed{url},
                                $parse->title() || "",
                                $entry->issued() || DateTime->from_epoch(epoch => time() - 604800),
                                $entry->title() || "", 
                                $entry->id(), 
                                $entry->link(),
                            );
                            my $id = $dbx->last_insert_id(undef,undef,undef,undef,{sequence=>'entry_id_seq'});
                            my $html_file = "$feed_path/$id.html";
                            # Mojo::Util::spurt(utf8::encode($entry->content->body()), $html_file);
                            File::Slurp::write_file($html_file, {binmode => ':utf8', atomic => 1}, $entry->content->body() || "No content found.");
                            $dbx->dbh->commit;
                        }
                    };
                    if ($@) {
                        my $err = $@;
                        info("INSERT INTO entry error(%s) :: %s", $$feed{url}, $err);
                        $dbx->dbh->rollback;
                    }
                }

                info("INSERT INTO entry :: %s :: %s", $$feed{url}, scalar(@{ $entries }));
            # }
        }

        $dbx->dbh->commit;
    }

    info("COMPLETE full scan");

    mem_usage();

    sleep(10);
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
    if (30_000 < $rss_pages) {
        info('exiting :: %s ', $rss_pages);

        exit 0;
    }
}
1;
