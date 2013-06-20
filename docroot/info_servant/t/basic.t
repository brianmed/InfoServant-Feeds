use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new();

$t->ua->max_redirects(10);

$t = $t->get_ok('http://infoservant.com');
$t = $t->status_is(200);
$t = $t->content_like(qr/InfoServant/i);

done_testing();
