#!/usr/bin/perl
use strict;

package Forum::Vanilla::Discussion;

use App::Options;
use Data::Dumper;
use Smart::Comments;
use Email::Address;
use Forum::Vanilla;

use DateTime;
use Moose;

has 'Vanilla' => (
    is  => 'rw',
    isa => 'Object',
);

has 'DiscussionID' => (
    is  => 'rw',
    isa => 'Int',
);

has 'LastCommentID' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

has 'Name' => (
    is  => 'rw',
    isa => 'Str',
);

has 'Body' => (
    is  => 'rw',
    isa => 'Str',
);

has 'Format' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Html',
);

has 'Hidden' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'No',
);

has 'CountComments' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

has 'Announce' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

# All discussions are by default placed in the category with id number 1.
# TODO: Let the user choose somehow which category a discussion should end up going into
has 'CategoryID' => (
    is => 'rw',
    isa => 'Int',
    default => '1',
);
    
has 'DateInserted' => (
    is  => 'rw',
    isa => 'DateTime',
);

has 'DateUpdated' => (
    is  => 'rw',
    isa => 'DateTime',
);

has 'DateLastComment' => (
    is  => 'rw',
    isa => 'DateTime',
);

has 'SenderEmailAddress' => (
    is  => 'rw',
    isa => 'Str',
);

has 'EmailMessageID' => (
    is  => 'rw',
    isa => 'Str',
);

has 'EmailOriginalMessage' => (
    is  => 'rw',
    isa => 'Str',
);

sub dump {
    my $self = shift;

    print Dumper($self);
}

sub dbhandle {
    my $self = shift;
    $self->{'Vanilla'} || die "No Vanilla object assigned!";
    return $self->{'Vanilla'}->{'dbhandle'};
}

sub table_name {
    my $self = shift;

    return $self->{'Vanilla'}->{'DISCUSSION_TBL'};
}

sub get_key_field_name {
    my $self = shift;

    return "DiscussionID";
}

# Get and return the id corresponding to the EmailMessageID for this message.
sub get_id {
    my $self = shift;

    my $van      = $self->{'Vanilla'};
    my $tbl      = $self->table_name();
    my $msgidcol = $van->{'EMAILMESSAGEID_COLUMN'};

    my $sth =
      $van->prepare( "select "
          . $self->get_key_field_name()
          . " from $tbl where $tbl.$msgidcol = ?" );

    my @args = ( $self->{'EmailMessageID'} );
    $van->execute( $sth, \@args );

    my $rows = 0;
    my $id   = -1;

    while ( my $row = $sth->fetch ) {
        $id = ${$row}[0];
        $rows++;
    }

    die "Expected to find one row with "
      . $self->{'EmailMessageID'}
      . " as the EmailMessageID and found "
      . $rows
      . " instead "
      if $rows != 1;
      
    return $id;
}

sub submit {
    my $self = shift;

    my $van      = $self->{'Vanilla'};
    my $tbl      = $self->table_name();
    my $msgidcol = $van->{'EMAILMESSAGEID_COLUMN'};

    $van->do("use $App::options{dbname}");

# Preparing discussion...
    my $sth =
      $van->prepare( "insert into $tbl "
          . "(LastCommentID, Name, Body, Format, Announce, SenderEmailAddress, "
          . "DateInserted, DateUpdated, DateLastComment, "
          . "EmailMessageID, EmailOriginalMessage, Hidden, CategoryID) "
          . "select ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? "
          . "from dual "
          . "where not exists (select * from $tbl where $tbl.$msgidcol = ?)" )
      or die " Cannot prepare new discussion ";

    my @args = (
        $self->{'LastCommentID'},        $self->{'Name'},
        $self->{'Body'},                 $self->{'Format'},
        $self->{'Announce'},             $self->{'SenderEmailAddress'},
        $self->{'DateInserted'},         $self->{'DateUpdated'},
        $self->{'DateLastComment'},      $self->{'EmailMessageID'},
        $self->{'EmailOriginalMessage'}, $self->{'Hidden'},
        $self->{'CategoryID'},

        $self->{'EmailMessageID'},
    );

# Executing discussion...
    my $rows = $van->execute( $sth, \@args, );

    return $rows;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
