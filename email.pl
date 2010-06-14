#!/usr/bin/perl
#
# Copyright (C) 2010 Aran Dunkley and others.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html
#
use Net::IMAP::Simple::SSL;
use Net::POP3;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::log  = "$1.log";

# Note the first ID of the last processed batch of messages if any
$::last = emailGetLastId() unless $::last < 0;


# Takes named parameters: proto, host, path, user, pass, from, to, subject, content
# - proto is "POP3" or "IMAP"
# - host is IP or domain
# - path is the folder to get the messages from
# - from,to,subject,content are optional regular exression filters
# - messages are read from most recent first
# - most recent id is recorded in the log to allow detection of previously processed items
sub emailGetMessages {
	my %args = %{ scalar shift };
	$args{filter} = {} unless defined $args{filter};
	my $server;
	
	# All messages in the inbox will be scanned and stored in @messages if rules match
	my @messages = ();

	# Only read this much from each message
	my $maxsize = 4096;

	# Process messages in a POP3 mailbox
	if ( $args{proto} eq 'POP3' ) {
		if ( $server = Net::POP3->new( $args{host} ) ) {
			emailLog( "Connected to $args{proto} server \"$args{host}\"" );
			if ( $server->login( $args{user}, $args{pass} ) > 0 ) {
				emailLog( "Logged \"$args{user}\" into $args{proto} server \"$args{host}\"" );
				for ( keys %{ $server->list() } ) {
					my $content = join "\n", @{ $server->top( $_, $maxsize ) };
					last unless my $message = emailProcessMessage( $content );
					push @messages, $message if emailMatchMessage( $message, $args{filter} );
				}
			} else { emailLog( "Couldn't log \"$args{user}\" into $args{proto} server \"$args{host}\"" ) }
			$server->quit();
		} else { emailLog( "Couldn't connect to $args{proto} server \"$args{host}\"" ) }
	}

	# Process messages in an IMAP mailbox
	elsif ( $args{proto} eq 'IMAP' ) {
		if ( $server = new Net::IMAP::Simple::SSL( $args{host} ) ) {
			if ( $server->login( $args{user}, $args{pass} ) > 0 ) {
				emailLog( "Logged \"$args{user}\" into IMAP server \"$args{host}\"" );
				$i = $server->select( $args{path} or 'Inbox' );
				while ( $i > 0 ) {
					$fh = $server->getfh( $i );
					sysread $fh, ( my $content ), $maxsize;
					close $fh;
					last unless my $message = emailProcessMessage( $content );
					push @messages, $message if emailMatchMessage( $message, $args{filter} );
					$i--;
				}
			} else { emailLog( "Couldn't log \"$args{user}\" into $args{proto} server \"$args{host}\"" ) }
			$server->quit();
		} else { emailLog( "Couldn't connect to $args{proto} server \"$args{host}\"" ) }
	}
	
	else { die "Unsupported email protocol \"$args{proto}\"" }

	return @messages;
}


# Expand the message into an useful hash and return a reference to it

# NOTE: combine matching and formatting/saving into processign function
#       needs to rul all rule-sets on each message

sub emailProcessMessage {
	my $content = shift;

	# Extract useful information from the message header
	my $id      = $1 if $content =~ /^message-id:\s*(.+?)\s*$/mi;
	my $date    = $1 if $content =~ /^date:\s*(.+?)\s*$/mi;
	my $to      = $1 if $content =~ /^to:\s*(.+?)\s*$/mi;
	my $from    = $1 if $content =~ /^from:\s*(.+?)\s*$/mi;
	my $subject = $1 if $content =~ /^subject:\s*(.+?)\s*$/im;

	# If this message has already been processed return null to bail
	if ( $::last eq $id ) {
		emailLog( "Message with ID $id has already been processed, stopping" );
		return undef;
	}
	
	# If this is the first message processed (which is the most recent of this batch) then log the ID
	unless ( $::logged ) {
		$::logged = 1;
		emailLog( "Processing a batch, first message ID is $id" );
	}

	# Return the useful information's hashref
	return {
		id      => $id,
		date    => $date,
		from    => $from,
		to      => $to,
		subject => $subject,
		content => $content
	}
}


# Returns true if the passed message array ref matches the regex's in @args
sub emailMatchMessage {
	my %message = %{ scalar shift };
	my %filter  = %{ scalar shift };
	my $pass    = 1;
	while ( ( $k, $v ) = each( %filter ) ) {
		$pass = 0 unless $message{$k} =~ /$v/sm;
	}
	return $pass;
}


# Output an item to the email log file with timestamp
sub emailLog {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}


# Scan the log for the ID of the last batch processed
sub emailGetLastId {
	if ( open FH, '<', $::log ) {
		my $size = -s $::log;
		seek FH, $size - 4096, 0; 
		read FH, ( my $out ), 4096;
		close FH;
		return $1 if $out =~ /.+first message ID is (.+?)$/sm;
	}
}

1;
