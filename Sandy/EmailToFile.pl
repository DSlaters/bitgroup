#!/usr/bin/perl
#
# Based on the GPL licenced www.organicdesign.co.nz/email.pl by Aran Dunkley, June 2010
#
use Net::IMAP::Simple::SSL;
use Net::POP3;
use Date::Parse;
use strict;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::log  = "$1.log";
require( "$1.cfg.pl" );

# Note the first ID of the last processed batch of messages if any
$::last = getLastId() unless $::last < 0;
logAdd();
logAdd( "$::daemon started..." );

# Loop through the sources
while ( my( $source, $args ) = each( %$::sources ) ) {
	logAdd( "Processing source \"$source\"..." );
	my $server;
	
	# Process messages in a POP3 mailbox
	if ( $$args{proto} eq 'POP3' ) {

		# Connect to POP3 server
		if ( $server = Net::POP3->new( $$args{host} ) ) {
			logAdd( "Connected to $$args{proto} server \"$$args{host}\"" );
			
			# Login in to POP3 server
			if ( $server->login( $$args{user}, $$args{pass} ) > 0 ) {
				logAdd( "Logged \"$$args{user}\" into $$args{proto} server \"$$args{host}\"" );
				
				# Loop through the rule-sets
				while ( my( $set, $rules ) = each( %$args ) ) {
					if ( ref( $rules ) eq 'HASH' ) {
						logAdd( "Matching messages against rule-set \"$set\"..." );

						# Loop through the messages
						for ( keys %{ $server->list() } ) {
							
							# Read message
							my $content = join "\n", @{ $server->top( $_, $::maxsize ) };
							
							# Process message
							last unless processMessage( $content, $rules );
						}						
					}
				}

			} else { logAdd( "Couldn't log \"$$args{user}\" into $$args{proto} server \"$$args{host}\"" ) }

			$server->quit();

		} else { logAdd( "Couldn't connect to $$args{proto} server \"$$args{host}\"" ) }
	}

	# Process messages in an IMAP mailbox
	elsif ( $$args{proto} eq 'IMAP' ) {

		# Connect to IMAP server
		if ( $server = new Net::IMAP::Simple::SSL( $$args{host} ) ) {
			
			# Login to IMAP server
			if ( $server->login( $$args{user}, $$args{pass} ) > 0 ) {
				logAdd( "Logged \"$$args{user}\" into IMAP server \"$$args{host}\"" );

				# Loop through the rule-sets
				while ( my( $set, $rules ) = each( %$args ) ) {
					if ( ref( $rules ) eq 'HASH' ) {
						logAdd( "Matching messages against rule-set \"$set\"..." );

						# Loop through messages
						my $i = $server->select( $$args{path} or 'Inbox' );
						while ( $i > 0 ) {
							
							# Read message
							my $fh = $server->getfh( $i-- );
							sysread $fh, my $content, $::maxsize;
							close $fh;

							# Process message
							last unless processMessage( $content, $rules );
						}						
					}
				}

			} else { logAdd( "Couldn't log \"$$args{user}\" into $$args{proto} server \"$$args{host}\"" ) }

			$server->quit();

		} else { logAdd( "Couldn't connect to $$args{proto} server \"$$args{host}\"" ) }
	}
	
	# Unsupported protocol
	else { logAdd( "Unsupported protocol \"$$args{proto}\"" ) }
}


# Process a message
# - match content against rules
# - if match is positive, format the result and write to file
# - return true to keep processing messages
sub processMessage {
	my $content = shift;
	my %ruleset = %{ scalar shift };
	my %message = ();

	# Extract useful information from the content
	$message{content} = $1 if $content =~ /\r?\n\r?\n(.+)$/s;
	$message{id}      = $1 if $content =~ /^message-id:\s*(.+?)\s*$/mi;
	$message{date}    = $1 if $content =~ /^date:\s*(.+?)\s*$/mi;
	$message{to}      = $1 if $content =~ /^to:\s*(.+?)\s*$/mi;
	$message{from}    = $1 if $content =~ /^from:\s*(.+?)\s*$/mi;
	$message{subject} = $1 if $content =~ /^subject:\s*(.+?)\s*$/im;
	$message{age}     = time() - str2time( $message{date} );
	
	# If this message has already been processed bail and stop processing messages
	if ( $::last eq $message{id} ) {
		logAdd( "Message $message{id} has already been processed, stopping batch" );
		return 0;
	}

	# If this message is older than allowed, bail and stop processing messages
	if ( $message{age} > $::maxage ) {
		logAdd( "Message $message{id} is older than the maximum allowed age of $::maxage seconds, stopping batch" );
		return 0;
	}

	# If this is the first message processed (which is the most recent of this batch) then log the ID
	unless ( $::logged ) {
		$::logged = 1;
		logAdd( "Processing a new batch, starting with $message{id}" );
	}

	# Apply the matching rules to the message and keep the captures for building the output
	my $match = 1;
	my %extract = ();
	while ( my( $field, $pattern ) = each( %{ $ruleset{rules} } ) ) {
		$match = 0 unless defined $message{$field} and $message{$field} =~ /$pattern/sm;
		$extract{$field} = [ 0, $1, $2, $3, $4, $5, $6, $7, $8, $9 ];
	}

	# If the message failed to match a rule, bail but keep processing more messages
	return 1 unless $match;

	# Build the output
	my $out = $ruleset{format};
	$out =~ s/\$$_(\d)/$extract{$_}[$1]/eg for keys %extract;
	logAdd( "Output is: \"$out\"" );

	# Write the output
	my $file = $ruleset{file};
	if ( $file =~ /\$1/ ) {
		
		# Find the next available filename
		my $i = 1;
		$file = $ruleset{file} and $file =~ s/\$1/$i++/e while -e $file;
				
		# Write the output to the new file
		if ( open OUTH, '>', $file ) {
			logAdd( "Writing message $message{id} to \"$file\"" );
			print OUTH $out;
			close OUTH;
		} else { logAdd( "Can't create \"$file\" for writing!" ) }

	} else {

		# Append the output to the new or existing file
		if ( open OUTH, '>>', $file ) {
			logAdd( "Appending message $message{id} to \"$file\"" );
			print OUTH $out;
			close OUTH;
		} else { logAdd( "Can't open \"$file\" for appending!" ) }

	}

	# Return true to keep processing
	return 1;
}


# Output an item to the email log file with timestamp
sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}


# Scan the log for the ID of the last batch processed
sub getLastId {
	if ( open FH, '<', $::log ) {
		my $size = -s $::log;
		seek FH, $size - 4096, 0; 
		read FH, ( my $out ), 4096;
		close FH;
		return $1 if $out =~ /.+starting with (.+?)$/sm;
	}
}
