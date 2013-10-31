#!/usr/bin/perl
use strict;

package Forum::Vanilla;

my $DISCUSSION_TBL = "GDN_Discussion";
my $COMMENTS_TBL   = "GDN_Comment";

my $EMAILMESSAGEID_COLUMN       = "EmailMessageId";
my $EMAILORIGINALMESSAGE_COLUMN = "EmailOriginalMessage";
my $SENDEREMAILADDRESS_COLUMN   = "SenderEmailAddress";
my $HIDDEN_COLUMN				= "Hidden";

# The tables, columns and their structures that are added to Vanilla by this program
# for custom tracking.
my @TABLE_STRUCTURES = (
    [ $DISCUSSION_TBL, $EMAILMESSAGEID_COLUMN,       'varchar(8192)', ],
    [ $DISCUSSION_TBL, $EMAILORIGINALMESSAGE_COLUMN, 'text', ],
    [ $DISCUSSION_TBL, $SENDEREMAILADDRESS_COLUMN,   'varchar(1024)', ],
    [ $COMMENTS_TBL,   $EMAILMESSAGEID_COLUMN,       'varchar(8192)', ],
    [ $COMMENTS_TBL,   $EMAILORIGINALMESSAGE_COLUMN, 'text', ],
    [ $COMMENTS_TBL,   $SENDEREMAILADDRESS_COLUMN,   'varchar(1024)', ],
    [ $COMMENTS_TBL,   $HIDDEN_COLUMN, 				"enum('Yes', 'No')", ],
    [ $COMMENTS_TBL,   $HIDDEN_COLUMN, 				"enum('Yes', 'No')", ],
);

# The SQL index tables and columns that are added to Vanilla by this program.
my @INDEX_STRUCTURES = (
    [ $DISCUSSION_TBL, $EMAILMESSAGEID_COLUMN ],
    [ $COMMENTS_TBL,   $EMAILMESSAGEID_COLUMN ],
);

use DBI;
use DBD::mysql;
use Data::Dumper;
use Moose;

# use Smart::Comments '###';

has 'DISCUSSION_TBL' => (
    is      => 'ro',
    isa     => 'Str',
    default => $DISCUSSION_TBL,
);

has 'COMMENTS_TBL' => (
    is      => 'ro',
    isa     => 'Str',
    default => $COMMENTS_TBL,
);

has 'EMAILMESSAGEID_COLUMN' => (
    is      => 'ro',
    isa     => 'Str',
    default => $EMAILMESSAGEID_COLUMN,
);

has 'EMAILORIGINALMESSAGE_COLUMN' => (
    is      => 'ro',
    isa     => 'Str',
    default => $EMAILORIGINALMESSAGE_COLUMN,
);

has 'SENDEREMAILADDRESS_COLUMN' => (
    is      => 'ro',
    isa     => 'Str',
    default => $EMAILORIGINALMESSAGE_COLUMN,
);

has 'dbhandle' => (
    is  => 'rw',
    isa => 'Object',
);

has '_need_indexes' => (
    is      => 'ro',
    isa     => 'Bool',
    default => undef,
);

has '_delete_columns' => (
    is      => 'ro',
    isa     => 'Bool',
    default => undef,
);

# database properties 
has 'driver' => ( is => 'rw', isa => 'Str', default => 'unknown');
has 'dbname' => ( is => 'rw', default => 'unknown');
has 'dbhost' => ( is => 'rw', default => 'unknown');
has 'dbport' => ( is => 'rw', default => 'unknown' );
has 'dbuser' => ( is => 'rw', default => 'unknown' );
has 'dbpass' => ( is => 'rw', isa => 'Str', default => 'unknown' );
has 'dbtrace' => ( is => 'rw', isa => 'Str', default => '0' );

sub connect_to_db {
    my $self = shift;

    DBI->trace( $self->{dbtrace} );

    my $dsn = "dbi:"
      . "$self->{driver}: "
      . "database=$self->{dbname};"
      . "host=$self->{dbhost};"
      . "port=$self->{dbport};";

    $self->{'dbhandle'} =
      DBI->connect( $dsn, $self->{dbuser}, $self->{dbpass},
        { RaiseError => 1, } )
      or die $DBI::errstr;

    $self->detect_vanilla_db();
}

# Assuming the database exists and is connected, searches for a table named $DISCUSSION_TBL within.
# Dies if it can't be found.
sub detect_vanilla_db {
    my $self = shift;

    my $rows =
      $self->{'dbhandle'}->do( "select * from information_schema.tables where "
          . " (table_schema = '$self->{dbname}') and "
          . " ( table_name = '$DISCUSSION_TBL')" );
    if ( $rows != 1 ) {
        die
"Could not detect vanilla installation, cannot find table $DISCUSSION_TBL in schema $self->{dbname}";
    }
}

sub do {
    my $self = shift;
    my $statement = shift || die "Do needs a SQL statement";

#### Executing SQL statement: $statement
    return $self->{'dbhandle'}->do($statement)
      or die "Cannot do SQL statement: $statement";
}

sub prepare {
    my $self = shift;
    my $statement = shift || die "Prepare needs a SQL statement";

#### Preparing SQL statement: $statement
    return $self->{'dbhandle'}->prepare($statement)
      or die "Cannot prepare SQL statement: $statement";
}

sub execute {
    my $self         = shift;
    my $sth          = shift;
    my $argumentsref = shift;

#### Self: $self
#### Statement handle: $sth
#### Arguments: $argumentsref

    $sth || die "Execute needs a statement handle from prepare()";

#### Executing SQL arguments: $argumentsref
    return $sth->execute( @{$argumentsref} )
      or die "Cannot execute SQL statement arguments: $argumentsref";
}

sub insert_column_if_not_exists {
    my $self = shift;

    my $table      = shift || die;
    my $column     = shift || die;
    my $columntype = shift || die;

    my $rows =
      $self->do( "select * from information_schema.columns where "
          . "(table_schema = '$self->{dbname}') and "
          . "( table_name = '$table' ) and "
          . "( column_name = '$column' )" )
      or die $DBI::errstr;

    if ( $rows == 0 ) {
### Can't find, adding it to database: $column
        $self->do("use $self->{dbname}")
          or die $DBI::errstr;

        $self->do("alter table $table add $column $columntype")
          or die $DBI::errstr;

        $rows =
          $self->do( "select * from information_schema.columns where "
              . "(table_schema = '$self->{dbname}') and "
              . "( table_name = '$table' ) and "
              . "( column_name = '$column' )" )
          or die $DBI::errstr;

        die "Couldn't create column $column of type $columntype in table $table"
          if ( $rows == 0 );

        $self->{'_need_indexes'} = 1;

    }
    else {
### Found column, not adding column to database: $column
    }
}

sub delete_column_if_exists {
    my $self = shift;

    my $table      = shift || die;
    my $column     = shift || die;
    my $columntype = shift || die;

    my $rows =
      $self->do( "select * from information_schema.columns where "
          . "(table_schema = '$self->{dbname}') and "
          . "( table_name = '$table' ) and "
          . "( column_name = '$column' )" );

    if ( $rows == 1 ) {
### Found and deleting column: $column
        $self->do("use $self->{dbname}")
          or die $DBI::errstr;

        $self->do("alter table $table drop $column")
          or die $DBI::errstr;

        $rows =
          $self->do( "select * from information_schema.columns where "
              . "(table_schema = '$self->{dbname}') and "
              . "( table_name = '$table' ) and "
              . "( column_name = '$column' )" )
          or die $DBI::errstr;

        die "Couldn't delete column $column of type $columntype in table $table"
          if ( $rows != 0 );

    }
    else {
        ### Not found, so can't delete column: $column
    }
}

sub insert_custom_columns {
    my $self = shift;

    foreach my $row (@TABLE_STRUCTURES) {
        my $table  = $row->[0];
        my $column = $row->[1];
        my $ctype  = $row->[2];

        ### Inserting...
        ### Table: $table
        ### Column: $column
        ### Column type: $ctype
        $self->insert_column_if_not_exists( $table, $column, $ctype );
    }
}

sub insert_custom_index {
    my $self = shift;

    my $table  = shift || die;
    my $column = shift || die;
    $self->do("use $self->{dbname}")
      or die $DBI::errstr;

    ### Table to create index for: $table
    ### Column to create index for: $column

    $self->do(
        "create index " . $column . "_Index on $table (" . $column . ")" )
      or die $DBI::errstr;

}

sub insert_custom_indexes {
    my $self = shift;

    if ( not $self->{'_need_indexes'} ) {
        return;
    }

    foreach my $row (@INDEX_STRUCTURES) {
        my $table  = $row->[0];
        my $column = $row->[1];

        ### Inserting...
        ### Table: $table
        ### Column: $column
        $self->insert_custom_index( $table, $column );
    }
}

sub delete_custom_columns {
    my $self = shift;

### Deleting custom columns...

    foreach my $row (@TABLE_STRUCTURES) {
        my $table  = $row->[0];
        my $column = $row->[1];
        my $ctype  = $row->[2];

### Deleting...
### Table: $table
### Column: $column
### Column type: $ctype
        $self->delete_column_if_exists( $table, $column, $ctype );
    }
}

sub does_messageid_exist_as_discussion {
    my $self = shift;

    my $messageid = shift;

    my $sth =
      $self->prepare("select * from $DISCUSSION_TBL where EmailMessageId=?");

    my $rows = $sth->execute($messageid);

    return ( $rows == 1 );
}

=pod ignore_this
sub insert_discussion {
    my $self       = shift;
    my $discussion = shift;

    if (
        not does_messageid_exist_as_discussion(
            $discussion->{'EmailMessageID'} ) )
    {
        return;
    }
}
=cut

sub setup {
    my $self = shift;
    $self->connect_to_db();
    $self->insert_custom_columns();
    $self->insert_custom_indexes();

    if ( $self->{'_delete_columns'} ) {
        $self->delete_custom_columns();
    }

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
