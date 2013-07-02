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

package InfoServant;

use Mojo::Base 'Mojolicious';

use SiteCode::Site;
use HTTP::BrowserDetect;
use IO::Compress::Gzip 'gzip';

sub is_mobile {
    my $self = shift;

    return(defined $self->mobile());
}

sub mobile {
    my $self = shift;

    my $agent = scalar $self->req->headers->header('user-agent');
    my $browser = HTTP::BrowserDetect->new($agent);
    return($browser->device());
}

sub compress {
    my ($c, $output, $format) = @_;

    # Check if "gzip => 1" has been set in the stash
    return unless $c->stash->{_gzip};

    # Check if user agent accepts GZip compression
    return unless ($c->req->headers->accept_encoding // '') =~ /gzip/i;
    $c->res->headers->append(Vary => 'Accept-Encoding');

    # Compress content with GZip
    $c->res->headers->content_encoding('gzip');
    gzip $output, \my $compressed;
    $$output = $compressed;
}

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->log->level("debug");

    my $site_config = SiteCode::Site->config();

    $self->config(hypnotoad => {listen => ["http://$$site_config{hypnotoad_ip}:80", "https://$$site_config{hypnotoad_ip}:443"], workers => 4, user => "root", group => "root", inactivity_timeout => 15, heartbeat_timeout => 15, heartbeat_interval => 15, accepts => 100});

    $self->helper(mobile => \&mobile);
    $self->helper(is_mobile => \&is_mobile);

    $self->hook(after_render => \&compress);

    # Increase limit to 10MB
    $ENV{MOJO_MAX_MESSAGE_SIZE} = 10485760;

    $self->plugin(AccessLog => {uname_helper => 'set_username', log => '/opt/infoservant.com/docroot/info_servant/log/access.log', format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});
    $self->plugin(tt_renderer => {template_options => {CACHE_SIZE => 0, COMPILE_EXT => undef, COMPILE_DIR => undef}});
    $self->plugin('ParamCondition');
    $self->plugin('SaveRequest');
    
    $self->renderer->default_handler('tt');

    $self->secret($$site_config{site_secret});
    
    # Router
    my $r = $self->routes;

    my $logged_in = $r->under (sub {
        my $self = shift;

        if (!$self->session("account_id")) {
            my $url = $self->url_for('/');
            return($self->redirect_to($url));
        }
        else {
             $self->set_username($self->session("account_id"));
        }
    });
    
    $r->get('/')->to(controller => 'Index', action => 'slash');

    $r->get('/login')->to(controller => 'Index', action => 'login');
    # $r->post('/login')->over(params => [qw(login password)])->over(save => "state")->to(controller => 'Index', action => 'login');
    $r->post('/login')->over(params => [qw(login password)])->to(controller => 'Index', action => 'login');

    $r->post('/signup')->over(params => {email => qr/\w/, username => qr/\w/, password => qr/\w/})->to(controller => 'Signup', action => 'add');
    $r->post('/signup')->to(controller => 'Signup', action => 'restart');
    $r->get('/signup')->to(controller => 'Signup', action => 'start');
    $r->any('/verify/#email/#verify')->to(controller => 'Signup', action => 'verify');
    $r->any('/verify')->to(controller => 'Signup', action => 'verify');

    $r->any('/change')->to(controller => 'Signup', action => 'change');
    $r->any('/reset/#email/#verify')->to(controller => 'Signup', action => 'change');
    $r->any('/reset')->to(controller => 'Signup', action => 'reset');

    # $r->any('/dashboard')->over(save => "state")->to(controller => 'Dashboard', action => 'show');
    $logged_in->any('/dashboard')->over(params => {method => qr/^verify$/})->to(controller => 'Dashboard', action => 'verify');
    $logged_in->any('/dashboard')->over(params => {method => qr/^new_feed$/})->to(controller => 'Dashboard', action => 'new_feed');
    $logged_in->any('/dashboard')->over(params => {method => qr/^opml_file$/})->to(controller => 'Dashboard', action => 'opml_file');
    $logged_in->any('/dashboard')->over(params => {method => qr/^unsubscribe$/})->to(controller => 'Dashboard', action => 'unsubscribe');
    $logged_in->any('/dashboard')->over(params => {method => qr/^purchase$/})->to(controller => 'Dashboard', action => 'purchase');
    $logged_in->any('/dashboard')->over(params => {method => qr/^cancel$/})->to(controller => 'Dashboard', action => 'cancel');
    $logged_in->any('/dashboard')->to(controller => 'Dashboard', action => 'show', _gzip => 1);
    $logged_in->any('/dashboard/details')->to(controller => 'Dashboard', action => 'details', _gzip => 1);

    $r->any('/stripe/:mode')->to(controller => 'Stripe', action => 'save');

    $r->any('/logout')->to(controller => 'Dashboard', action => 'logout');
}

1;
