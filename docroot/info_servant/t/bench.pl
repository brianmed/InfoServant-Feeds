use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Benchmark qw(timethese);

my $t = Test::Mojo->new();

$t->ua->max_redirects(10);

timethese(
    3_000,
    {
        Index => sub {
            $t = $t->get_ok('http://infoservant.com');
            $t = $t->status_is(200);
        },

        Login => sub {
           $t->post_ok('https://infoservant.com/login' => form => {login => 'pub-kazetzetfy@bmedley.org', password => 'IAmHE'})
                ->status_is(200)
        },
    }
);


done_testing();
