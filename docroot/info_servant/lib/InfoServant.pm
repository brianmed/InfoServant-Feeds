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

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->log->level("debug");

    $self->config(hypnotoad => {listen => ['http://64.91.254.80:80', 'https://64.91.254.80:443'], workers => 15, user => "bpm", group => "bpm", inactivity_timeout => 15, heartbeat_timeout => 15, heartbeat_interval => 15, accepts => 50});

    # Increase limit to 10MB
    $ENV{MOJO_MAX_MESSAGE_SIZE} = 10485760;

    $self->plugin(AccessLog => {log => '/opt/infoservant.com/docroot/info_servant/log/access.log'});
    $self->plugin(tt_renderer => {template_options => {CACHE_SIZE => 0}});
    $self->plugin('ParamCondition');
    $self->plugin('SaveRequest');
    
    $self->renderer->default_handler('tt');

    my $site_config = SiteCode::Site->config();
    $self->secret($$site_config{site_secret});
    
    # Router
    my $r = $self->routes;
    
    $r->get('/')->to(controller => 'Index', action => 'slash');

    $r->get('/login')->to(controller => 'Index', action => 'login');
    $r->post('/login')->over(params => [qw(login password)])->to(controller => 'Index', action => 'login');

    $r->post('/signup')->over(params => {username => qr/\w/, email => qr/\w/, vemail => qr/\w/, password => qr/\w/})->to(controller => 'Signup', action => 'add');
    $r->post('/signup')->to(controller => 'Signup', action => 'restart');
    $r->get('/signup')->to(controller => 'Signup', action => 'start');
    $r->any('/verify/#email/#verify')->to(controller => 'Signup', action => 'verify');
    $r->any('/verify')->to(controller => 'Signup', action => 'verify');

    $r->any('/dashboard')->to(controller => 'Dashboard', action => 'show');
    $r->any('/dashboard/html/:page')->to(controller => 'Dashboard', action => 'retrieve_html');
    # $r->any('/dashboard/html/:page')->over(save => "state")->to(controller => 'Dashboard', action => 'retrieve_html');
    $r->any('/dashboard/javascript/:page')->to(controller => 'Dashboard', action => 'retrieve_js');
    $r->get('/dashboard/feed/src/:feed_nbr')->to(controller => 'Dashboard', action => 'retrieve_feed_src');
    $r->get('/dashboard/feed/link/:feed_nbr')->to(controller => 'Dashboard', action => 'retrieve_feed_link');
    $r->get('/dashboard/feed/entries/:feed_nbr')->to(controller => 'Dashboard', action => 'retrieve_feed_entries');

    $r->any('/logout')->to(controller => 'Dashboard', action => 'logout');
}

1;
