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

package InfoServant::Stripe;

use Mojo::Base 'Mojolicious::Controller';

use SiteCode::DBX;
use POSIX;
use File::Temp;

use Mojo::Util;

sub save {
    my $self = shift;

    my $mode = $self->param("mode");

    my $dir = POSIX::strftime("/opt/infoservant.com/stripe/%F", localtime(time));
    mkdir $dir unless -d $dir;
    my ($fh, $filename) = File::Temp::tempfile("${mode}XXXXX", DIR => $dir, SUFFIX => '.txt', UNLINK => 0);
    print($fh $self->req->body);
    close($fh);

    $self->render(data => '', status => 200);
}

1;
