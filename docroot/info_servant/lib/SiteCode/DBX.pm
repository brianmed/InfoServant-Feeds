package SiteCode::DBX;

use Moose;
use namespace::autoclean;
use DBI;
use Carp;

has 'dbdsn' => ( isa => 'Str', is => 'ro', default => 'dbi:Pg:dbname=scotch_egg' );
has 'dbh' => ( isa => 'DBI::db', is => 'ro', lazy => 1, builder => '_build_dbh' );

sub _build_dbh {
    my $self = shift;

    return DBI->connect($self->dbdsn(), "kevin", "the_trinity", { RaiseError => 1, PrintError => 0, AutoCommit => 1, pg_server_prepare => 0 });
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
    if ($ret) {
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
