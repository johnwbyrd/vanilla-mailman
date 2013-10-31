#!/usr/bin/perl
use strict;

package Forum::Vanilla::Comment;

use App::Options;
use Data::Dumper;
use Smart::Comments;
use Email::Address;
use Forum::Vanilla;

use DateTime;
use Moose;

extends 'Forum::Vanilla::Discussion';

sub table_name {
    my $self = shift;

    return $self->{'Vanilla'}->{'COMMENTS_TBL'};
}

sub get_key_field_name {
    my $self = shift;

    return "CommentID";
}

sub submit {
    my $self = shift;

    my $van      = $self->{'Vanilla'};
    my $tbl      = $self->table_name();
    my $msgidcol = $van->{'EMAILMESSAGEID_COLUMN'};

# Use Vanilla database...
    $van->do("use $App::options{dbname}");

# Preparing comment...
    my $sth =
      $van->prepare( "insert into $tbl "
          . "(Body, Format, SenderEmailAddress, "
          . "DateInserted, DateUpdated, "
          . "EmailMessageID, EmailOriginalMessage, Hidden, DiscussionID) "
          . "select ?, ?, ?, ?, ?, ?, ?, ?, ? "
          . "from dual "
          . "where not exists (select * from $tbl where $tbl.$msgidcol = ?)" )
      or die " Cannot prepare new discussion ";

    my @args = (
        $self->{'Body'}, $self->{'Format'},
        $self->{'SenderEmailAddress'},
        $self->{'DateInserted'}, $self->{'DateUpdated'},
        $self->{'EmailMessageID'},
        $self->{'EmailOriginalMessage'}, $self->{'Hidden'},
        $self->{'DiscussionID'},

        $self->{'EmailMessageID'},
    );

# Executing comment...
    my $rows = $van->execute( $sth, \@args, );

    return $rows;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
