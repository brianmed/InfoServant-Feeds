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

package SiteCode::DBX;

use SiteCode::Modern;

use Moose;
use namespace::autoclean;

use DBI;
use Carp;
# use DBIx::Connector

has 'dbdsn' => ( isa => 'Str', is => 'ro', default => 'dbi:Pg:dbname=scotch_egg' );
has 'dbh' => ( isa => 'DBI::db', is => 'ro', lazy => 1, builder => '_build_dbh' );
has 'route' => ( isa => 'Mojolicious::Controller', is => 'ro' );
# has 'dbix' => ( isa => 'DBIx::Connector', is => 'ro', lazy => 1, builder => '_build_dbix' );

sub _build_dbh {
    my $self = shift;

    my $dbh = DBI->connect($self->dbdsn, "kevin", "the_trinity", {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 0,
        pg_server_prepare => 0,
        pg_enable_utf8 => 1,
    });

    return($dbh);
}

sub do {
    my $self = shift;
    my $sql = shift;
    my $attrs = shift;
    my @vars = @_;

    if (ref($self)) {
        eval {
            return($self->dbh()->do($sql, $attrs, @vars));
        };
        if ($@) {
            croak("$@");
        }
    }
    else {
        my $dbh = $self->_build_dbh();
        return($dbh->do($sql, $attrs, @vars));
    }
}

sub success {
    my $self = shift;
    my $sql = shift;
    my $attrs = shift;
    my @vars = @_;

    my $ret = $self->dbh()->do($sql, $attrs, @vars);
    if (0 && $self->route()) {
        $self->route->app->log->debug("ret: $ret");
    }
    if ($ret && 0 != $ret) {  # 0E0
        return(1);
    }

    return(0);
}

sub last_insert_id
{
    my $self = shift;

    my $catalog = shift;
    my $schema = shift;
    my $table = shift;
    my $field = shift;
    my $attrs = shift;

    if ($attrs) {
        return($self->dbh()->last_insert_id(undef,undef,undef,undef,$attrs));
    }
    else {
        return($self->dbh()->last_insert_id($catalog, $schema, $table, $field, undef));
    }
}

sub col {
    my $self = shift;
    my $sql = shift;
    my $attrs = shift;
    my @vars = @_;

    # warn("sql: $sql");
    # warn("attrs: $attrs");
    # warn("vars: ", join("//", @vars));
    my $ret = $self->dbh()->selectcol_arrayref($sql, $attrs, @vars);
    if ($ret && $$ret[0]) {
        # warn(qq(return($$ret[0])));
        return($$ret[0]);
    }
    # warn(qq(return($ret)));

    return(undef);
}

sub row {
    my $self = shift;
    my $sql = shift;
    my $attrs = shift;
    my @vars = @_;

    # warn("sql: $sql");
    # warn("attrs: $attrs");
    # warn("vars: ", join("//", @vars));
    my $ret = $self->dbh()->selectall_arrayref($sql, { Slice => {} }, @vars);
    if ($ret && $$ret[0]) {
        # warn(qq(return($$ret[0])));
        return($$ret[0]);
    }
    # warn(qq(return($ret)));

    return(undef);
}

sub question
{
    my $self = shift;
    my $nbr = shift;

    return(join(", ", map({"?"} (1 .. $nbr))));
}

sub array {
    my $self = shift;
    my $sql = shift;
    my $attrs = shift;
    my @vars = @_;

    # warn("sql: $sql");
    # warn("attrs: $attrs");
    # warn("vars: ", join("//", @vars));
    my $ret = $self->dbh()->selectall_arrayref($sql, { Slice => {} }, @vars);
    if ($ret) {
        return($ret);
    }
    # warn(qq(return($ret)));

    return(undef);
}

sub DEMOLISH {
    my $self = shift;

    # $self->dbh()->disconnect();
}

__PACKAGE__->meta->make_immutable;

1;
