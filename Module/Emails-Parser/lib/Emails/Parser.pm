#!/usr/bin/perl

package Emails::Parser;
$Emails::Parser::VERSION = '0.1';

use 5.006;
use strict;

=head1 NAME

Emails::Parser - parses a collection of messages for pushing into a forum

=head1 SYNOPSIS

Collects a bunch of messages (typically in mbox format, though you can use any
format supported by Mail::Box) and pushes them into a forum.

=head1 DESCRIPTION

This object represents an abstraction for an email parser.  It will read a Mail::Box 
full of information, parse it into threads, and then sort the messages into 
an online discussion forum.  It currently does this by accessing the database
in which the forum messages are stored.

=cut

=head1 OPTIONS

=over 8

=item B<--driver>=I<mysql>

Specifies the database driver to be used for this parser.  Also checks the DBI_DRIVER
environmental flag for the name of this driver.  The name of any installed DBI 
driver module should work.  The default is I<mysql>.

=cut

use App::Options (
    options => [
        "driver",         "dbhost",
        "dbport",         "dbname",
        "dbuser",         "dbpass",
        "dbtrace",        "mailboxtype",
        "mailfolderdirs", "mailfolder",
        "mailuser",       "mailpass",
        "mailservername", "mailserverport",
        "mailtrace",      "maillistname"
    ],

    option => {
        driver => {
            description => "database driver name",
            env         => "DBI_DRIVER",
            default     => "mysql",
        },

        dbhost => {
            description => "database host",
            default     => "cinematic.gigantic",
        },

        dbport => {
            description => "database port",
            default     => 3306,
        },

        dbname => {
            description => "name of database for vanilla forum",
            default     => "vanilla",
        },

        dbuser => {
            description => "database user",
            env         => "DBI_USER",
            default     => "vanilla_update",
        },

        dbpass => {
            description => "database password",
            env         => "DBI_PASSWORD",
            default     => "change_me",
            secure      => 1,
        },

        dbtrace => {
            description =>
              "database trace flags, see 'Tracing' in DBI.pm for details",
            env     => "DBI_TRACE",
            default => "0",
        },

        mailboxtype => {
            description =>
"type of mailbox to be opened, try one of: imap imap4 maildir mbox mh pop pop3 pop3s",
            default => "mbox",
        },

        mailfolderdirs => {
            description =>
"list of folder locations to be searched, e.g. the location of the mailbox",
            default => "mbox",
        },

        mailfolder => {
            description => "The default mail folder to be read from",
            default     => "mbox",
        },
        mailuser => {
            description => "mail server user",
            default     => "user\@mail-server.com",
        },
        mailpass => {
            description => "mail server password (if any)",
            default     => "change_me",
            secure      => 1,
        },
        mailservername => {
            description =>
              "the name of the machine from which mail is to be read",
            default => "localhost",
        },

        mailserverport => {
            description => "name of the port from which mail is to be read",
            default     => 143,
        },

        mailtrace => {
            description =>
"mail tracing settings for Mail::Box, one of INTERNAL ERRORS WARNINGS PROGRESS NOTICES DEBUG NONE",
            default => "WARNINGS",
        },

        maillistname => {
            description => "name of the mailing list",
            default     => "maillistname",
        }
    },
);

use Mail::Box::Manager;
use Mail::Thread;
use Mail::Thread::Chronological;
use HTML::FormatText;
use HTML::TreeBuilder;
use Mail::Message::Convert::TextAutoformat;
use Text::Autoformat;
use Email::Address;

# use Smart::Comments '###';
use Data::Dumper;
use Text::Markdown 'markdown';
use DateTime;
use Term::ProgressBar::Quiet;
use Term::ProgressBar::Simple;
use Forum::Vanilla;
use Forum::Vanilla::Discussion;
use Forum::Vanilla::Comment;
use Moose;

=back

=head1 FUNCTIONS

=over 8

=item I<forum>

A Moose read-only object containing a Forum::Vanilla.

=cut

sub _build_forum {
    my $self = shift;
    my $forum;

    $forum = Forum::Vanilla->new(
        driver  => $App::options{driver},
        dbname  => $App::options{dbname},
        dbhost  => $App::options{dbhost},
        dbport  => $App::options{dbport},
        dbuser  => $App::options{dbuser},
        dbpass  => $App::options{dbpass},
        dbtrace => $App::options{dbtrace},
    );

    ### The forum is now: $forum

    return $forum;
}

has 'forum' => (
    is      => 'rw',
    isa     => 'Forum::Vanilla',
    builder => '_build_forum'
);

=item I<most_recent_discussion_id>

A Moose read-only object containing the forum's id of the discussion that the
parser has seen most recently.  Relevant for figuring out which discussion comments
ought to be threaded into.

=cut

has 'most_recent_discussion_id' => (
    is      => 'ro',
    isa     => 'Int',
    default => '-1',
);

has 'num_messages' => (
    is      => 'ro',
    isa     => 'Int',
    default => '0',
);

has 'progress_bar' => (
    'is'  => 'ro',
    'isa' => 'Term::ProgressBar::Quiet',
);

# Display all the options passed to this program.
sub display_options_passed {
    my $self = shift;
    print "Display options passed to the command line:\n";
    foreach ( sort keys %App::options ) {    # options appear here!
        printf( "%s => %s\n", $_, $App::options{$_} );
    }
}

=item I<clean_subject()>

Removes Re:'s, the name of the previous mailing list, and other previous cruft
from a subject line.  Returns the cleaned subject.

=cut

sub clean_subject {
    my $self    = shift;
    my $subject = shift;

    $subject =~ s/\[$App::options{maillistname}\] //;
    $subject =~ s/[Rr][Ee][\[0-9\]]*: //;
    $subject =~ s/[Rr][Ee] : //;
    return $subject;
}

sub get_message_id {
    my $self = shift;
    my $msg  = shift;

    my $messageId;
    $messageId = $msg->get('X-Original-MessageID');

    if ( not defined($messageId) ) {
        $messageId = $msg->messageId;
    }

    return $messageId;
}

sub get_message_text {
    my $self = shift;
    my $msg  = shift;
    my $af   = Mail::Message::Convert::TextAutoformat->new;

    if ( $msg->isMultipart() ) {

        # it's multipart, better dissect it
        foreach my $attachment ( $msg->parts ) {
            if ( $attachment->contentType() eq 'text/plain' ) {

                return $attachment->body;
            }
        }
    }
    else {

        # it's single part, just grab it
        if ( $msg->contentType() eq 'text/plain' ) {
            return $msg->body;
        }
    }

    die "Nothing to display in this message!";
    return '';
}

sub determine_original_sender {
    my $self = shift;

    my $body = shift;
    my $msg  = shift;
    my $sender;
    my @from;

    ### First, look in the X-OriginalSender field (if any).
    $sender = $msg->get('X-OriginalSender');

    if ( not $sender ) {

### That didn't work, look for the From field embedded within the body of the message
        $sender = $self->try_to_find_sender_in_body($body);
        if ( not $sender ) {

            if ( not defined( $msg->from ) ) {
                print $msg->from;
                die("This message doesn't seem to have a From field: $msg");
            }

### That didn't work, use the real sender from the header of the message (not likely to be correct)
            @from = $msg->from;

### Here's the message from field: @from

            if ( not @from ) {
                die
"I couldn't figure out the from field for messageId: $msg->messageId";
            }
            else {

                ### Sender found in header: $from[0]->format
                return $from[0]->format;
            }
        }
        else {

            ### Sender found in body: $sender
            return $sender;
        }
    }
    else {

        # Sender found in special header field: $sender
        return $sender;
    }
    return ();
}

sub try_to_find_sender_in_body {
    my $self = shift;
    my $msg  = shift;
    my $sender;

    if ( $msg =~ m/^This e-mail originated from: (.+)One-line bio:/s ) {
        ### I think the sender was: $1
        return $1;
    }

    if ( $msg =~ m/^From: (.+)/m ) {
        return $1;
    }

    return undef;
}

sub remove_body_cruft {
    my $self = shift;
    my $body = shift;

    # Remove inline From:
    $body =~ s/From: .+//m;

# Destroy to the end if we see "---".
# This takes care of the footer as well as -----Original Message----- type things.
    $body =~ s/---.+//s;

    # Destroy to the end if we see "One line bio"
    $body =~ s/One-line bio:.+//s;

    # Destroy to the end if we see "Sent from my"
    $body =~ s/Sent from my .+//s;

    # Search and replace janky quotes
    $body =~ s/“/\"/g;
    $body =~ s/”/\"/g;
    $body =~ s/’/\'/g;

    # Search and destroy end of line = and =20
    $body =~ s/=\n//g;
    $body =~ s/=20//g;

    return $body;
}

sub auto_format_body {
    my $self = shift;
    my $msg  = shift;

    $msg = autoformat( $msg, { mail => 1, widow => 3 } );

    return $msg;
}

sub find_datetime {
    my $self = shift;
    my $msg = shift || die "I need a message";

    my $stamp = $msg->timestamp();
    my $datetime = DateTime->from_epoch( epoch => $stamp );

    return $datetime;
}

# Prints information about a particular mail thread.
sub walk_through_messages {

    my ( $self, $containerlist, $level ) = @_;

    if ( $containerlist->message ) {
        my $msg = $containerlist->message;

        $self->{'progress_bar'}++;

        my $messageID = $self->get_message_id($msg);
        ### MessageID: $messageID

        my $body     = $self->get_message_text($msg);
        my $sender   = $self->determine_original_sender( $body, $msg );
        my $datetime = $self->find_datetime($msg);

        my @emails = Email::Address->parse($sender);
        #### Emails: @emails

# There seem to be a few funked-up emails that cause this value to be empty.  Not quite sure
# why this is, but punt on this case.
        my $firstemails = $emails[0];
        if ( defined($firstemails) ) {

            my $email = $emails[0]->address;

            #### Level: $level
            #### From: $sender
            #### Email: $email

            $body = $self->remove_body_cruft($body);
            $body = $self->auto_format_body($body);
					
            # Don't format the body if it's null
            if ( defined $body ) {
                $body = markdown( $body );
            } else {
                $body = "\n\n";
            }

            my $sbj = $self->clean_subject( $msg->subject );
            #### Subject: $sbj;
            #### Body: $body
            #### Body end
			
            if ( $level == 0 ) {
                ### Handling discussion...
                my $discussion = Forum::Vanilla::Discussion->new;

                $discussion->{'Vanilla'}            = $self->{'forum'};
                $discussion->{'Name'}               = $sbj;
                $discussion->{'Body'}               = $body;
                $discussion->{'EmailMessageID'}     = $messageID;
                $discussion->{'SenderEmailAddress'} = $email;

                $discussion->{'DateInserted'}    = $datetime;
                $discussion->{'DateUpdated'}     = $datetime;
                $discussion->{'DateLastComment'} = $datetime;

                $discussion->submit();

                my $discussion_id = $discussion->get_id();
                $self->{'most_recent_discussion_id'} = $discussion_id;

                # The ID is: $discussion_id
            }
            else {
                ### Handling comment...

                my $comment = Forum::Vanilla::Comment->new;

                $comment->{'Vanilla'}            = $self->{'forum'};
                $comment->{'Body'}               = $body;
                $comment->{'EmailMessageID'}     = $msg->messageId;
                $comment->{'SenderEmailAddress'} = $email;

                $comment->{'DateInserted'}    = $datetime;
                $comment->{'DateUpdated'}     = $datetime;
                $comment->{'DateLastComment'} = $datetime;

                die
"Most recent discussion ID doesn't exist -- that shouldn't happen"
                  if ( $self->{'most_recent_discussion_id'} == -1 );

                $comment->{'DiscussionID'} =
                  $self->{'most_recent_discussion_id'};

                $comment->submit();
            }
        }

    }
    else {
        if ( $level == 0 ) {

# This is a dummy message.  It represents a missing message in the thread, usually at the
# root.  It needs to be dealt with as though the discussion exists even though it can't
# be found at the current time.

            my $msg = $containerlist->topmost->message;

            my $datetime = $self->find_datetime($msg);
            my $sbj      = $self->clean_subject( $msg->subject );

            ### Handling dummy discussion...
            my $discussion = Forum::Vanilla::Discussion->new;

            $discussion->{'Vanilla'}        = $self->{'forum'};
            $discussion->{'Name'}           = $sbj;
            $discussion->{'Body'}           = '';
            $discussion->{'EmailMessageID'} = $msg->messageId . "-dummy-parent";

            $discussion->{'DateInserted'}    = $datetime;
            $discussion->{'DateUpdated'}     = $datetime;
            $discussion->{'DateLastComment'} = $datetime;

            # Dummy discussion is: $discussion

            $discussion->submit();

            my $discussion_id = $discussion->get_id();
            $self->{'most_recent_discussion_id'} = $discussion_id;
        }
        else {
            # These seem to occur, so I'm not sure if this is an error or not.
            # die "I found a dummy message somewhere which is not at the root of the message hierarchy!";
        }
    }

    if ( $containerlist->child ) {
        ### Recursing downward...
        $self->walk_through_messages( $containerlist->child, $level + 1 );
        ### Recursing upward...
    }

# Don't kill the most recent diuscussion -- there may be other children of an invented discussion
# $self->{'most_recent_discussion_id'} = '-1';

    if ( $containerlist->next ) {
        ### Recursing rightward...
        $self->walk_through_messages( $containerlist->next, $level );
        ### Recursing leftward...
    }
}

sub do_threading {
    my $self = shift;
    my $mgr = new Mail::Box::Manager( autodetect => $App::options{type}, );

    #print "\nTypes of folders detected: "
    #      . join( " ", $mgr->folderTypes, " " ) . "\n\n";

    my $barReadingMessages = Term::ProgressBar::Quiet->new(
        {
            name  => 'Reading mail folder',
            count => 1,
        }
    );

    my $folder = $mgr->open(
        folder      => $App::options{mailfolder},
        type        => $App::options{mailboxtype},
        username    => $App::options{mailuser},
        password    => $App::options{mailpass},
        server_name => $App::options{mailservername},
        server_port => $App::options{mailserverport},
        trace       => $App::options{mailtrace},
        log         => $App::options{mailtrace},
    );

    $self->{'num_messages'} = scalar( $folder->messages );

    my $threader = new Mail::Thread( $folder->messages );
    $barReadingMessages->update(1);
    undef $barReadingMessages;

    my $barThreading = Term::ProgressBar::Quiet->new(
        {
            name  => 'Threading messages',
            count => 1,
        }
    );
    $threader->thread;

    my @sroot = sort { $b <=> $a } ( $threader->rootset );
    $barThreading->update(1);
    undef $barThreading;

    $self->{'progress_bar'} = Term::ProgressBar::Simple->new(
        {
            name  => 'Pushing messages to forum',
            count => $self->{'num_messages'},
        }
    );

    $self->walk_through_messages( $_, 0 ) for @sroot;

    $mgr->close();
}

sub parse {
    my $self = shift;

    $self->{'forum'}->setup();
    $self->do_threading();
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__
 
 
=back

=head1 AUTHOR

John Byrd, I<jbyrd at giganticsoftware dot com>

=head1 LICENSE

http://creativecommons.org/licenses/by/3.0/deed.en_US
 
=cut
