#!/usr/bin/perl
#
# Copyright (C) 2009-2010 Aran Dunkley
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
use POSIX qw( strftime setsid );
use Net::IMAP::Simple;
use Net::IMAP::Simple::SSL;
use Cwd qw( realpath );
use strict;

$::ver    = '1.1.0'; # 2010-09-07
$::daemon = 'mtserver';
$::limit  = 4096;
$::maxage = 3600 * 12;

# Ensure CWD is in the dir containing this script
chdir $1 if realpath( $0 ) =~ m|^(.+)/|;
$::dir = $1;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::log = "$1.log";
require( "$1.conf" );
logAdd();
logAdd( "$::daemon-$::ver" );

# Run as a daemon (see daemonise.pl article for more details and references regarding perl daemons)
open STDIN, '/dev/null';
open STDOUT, ">>$::log";
open STDERR, ">>$::log";
defined ( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";
umask 0;
$0 = "$::daemon ($::ver)";

# Install the service into init.d and rc2-5.d if --install arg passed
if ( $ARGV[0] eq '--install' ) {
	writeFile( my $target = "/etc/init.d/$::daemon", "#!/bin/sh\n/usr/bin/perl $::dir/$::daemon.pl\n" );
	symlink $target, "/etc/rc$_.d/S99$::daemon" for 2..5;
	symlink "$::dir/$::daemon.pl", "/usr/bin/$::daemon";
	chmod 0755, "/etc/init.d/$::daemon";
	logAdd( "$::daemon added to /etc/init.d and /usr/bin" );
}

# Remove the named service and exit
if ( $ARGV[0] eq '--remove' ) {
	unlink "/etc/rc$_.d/S99$::daemon" for 2..5;
	unlink "/etc/init.d/$::daemon.sh";
	unlink "/usr/bin/$::daemon";
	logAdd( "$::daemon.sh removed from /etc/init.d and /usr/bin" );
	exit 0;
}

# Main loop
while( 1 ) {
	checkMessages();
	sleep 5;
}


# Read and return content from passed file
sub readFile {
	my $file = shift;
	if ( open FH, '<', $file ) {
		binmode FH;
		sysread FH, ( my $out ), -s $file;
		close FH;
		return $out;
	}
}


# Write passed content to passed file
sub writeFile {
	my $file = shift;
	if ( open FH,'>', $file ) {
		binmode FH;
		print FH shift;
		close FH;
		return $file;
	}
}


# Function for spawning a child to execute a function by name
sub spawn {
	my $subname = shift;
	my $subref = eval '\&$subname';
	$SIG{CHLD} = 'IGNORE';
	if ( defined( my $pid = fork ) ) {
		if ( $pid ) { logAdd( "Spawned child ($pid) for \"$subname\"" ) }
		else {
			$::subname = $subname;
			$0 = "$::daemon: $::name ($subname)";
			&$subref( @_ );
			exit;
		}
	}
	else { logAdd( "Cannot fork a child for \"$subname\": $!" ) }
}


# Output an item to the email log file with timestamp
sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}


# Check the passed email source for messages to process
sub checkMessages {
	for my $source ( keys %$::sources ) {
		logAdd( "Processing source \"$source\"..." ) if $::debug;
		my %args = $$::sources{$source};
		my $server = $args{ssl} ? Net::IMAP::Simple::SSL->new( $args{host} ) : Net::IMAP::Simple->new( $args{host} );
		if ( $server ) {
			if ( $server->login( $args{user}, $args{pass} ) > 0 ) {
				logAdd( "Logged \"$args{user}\" into IMAP server \"$args{host}\"" ) if $::debug;
				my $i = $server->select( $args{path} or 'Inbox' );
				logAdd( ( $i ? $i : 'No' ) . ' messages to scan' ) if $::debug;
				while ( $i > 0 ) {
					if ( my $fh = $server->getfh( $i ) ) {
						sysread $fh, ( my $content ), $::limit;
						close $fh;
						processMessage( $source, $content );
						$server->delete( $i );
					}
					$i--;
				}
			} else { logAdd( "Couldn't log \"$args{user}\" into $args{proto} server \"$args{host}\"" ) }
			$server->quit();
		} else { logAdd( "Couldn't connect to $args{proto} server \"$args{host}\"" ) }
	}
}


# Parse content from a single message
# - match content against rules
# - if match is positive, format the result and write to file
# - return true if any matches
sub processMessage {
	my $source  = shift;
	my $content = shift;

	# Extract useful information from the content
	my %message = ();
	$message{content} = $1 if $content =~ /\r?\n\r?\n\s*(.+?)\s*$/s;
	$message{id}      = $1 if $content =~ /^message-id:\s*(.+?)\s*$/mi;
	$message{date}    = $1 if $content =~ /^date:\s*(.+?)\s*$/mi;
	$message{to}      = $1 if $content =~ /^to:\s*(.+?)\s*$/mi;
	$message{from}    = $1 if $content =~ /^from:\s*(.+?)\s*$/mi;
	$message{subject} = $1 if $content =~ /^subject:\s*(.+?)\s*$/im;

	# Strip HTML tags from content
	$message{content} =~ s|<[^<>]+>||g;

	if( $::debug ) {
		logAdd( "Message received from $message{from}" );
		logAdd( "   To: $message{to}" );
		logAdd( "   Subject: $message{subject}" );
		logAdd( "   Content: $message{content}" );
	}

	# Apply the matching rules to the message and keep the captures for building the output
	my %extract = ();
	my %rules   = ();
	my $match   = 0;
	my $count   = 0;
	for my $k ( keys %$::ruleset ) {
		logAdd( "   Ruleset: $k" ) if $::debug;
		%rules = %{$$::ruleset{$k}};
		for my $field ( keys %{$rules{rules}} ) {
			my $pattern  = $rules{rules}{$field};
			my $captures = $pattern =~ tr/)// || 1; # <----- $captures must not be zero
			logAdd( "      Rule: $field => $pattern" ) if $::debug;
			logAdd( "         Captures: $captures" ) if $::debug;

			# Apply the rule's pattern and extract all matches if any
			# - all existing field patterns must match
			$match = 1;
			if( defined $message{$field} ) {
				$extract{$field} = [];
				my @matches = $message{$field} =~ /$pattern/gms;
				$match = 0 if $#matches < 0;
				$count = 0;
				while( $#matches >=0 ) {
					$count++;
					my @row = ();
					push @row, shift @matches for 1 .. $captures;
					push @{$extract{$field}}, \@row;
				}
			}
			$match = 0 unless $count;

			logAdd( "         Match failed!" ) unless $match or not $::debug;
			logAdd( "         Matches: $count x $captures" ) if $match and $::debug;
		}
		last if $match;
	}

	# Format the matches and ensure no duplicates
	my %outputs = ();
	for my $i ( 1 .. $count ) {
		logAdd( "   Formatting output $i of $count" ) if $::debug;
		my $out = $rules{format};
		$out =~ s/\$$_(\d)/$extract{$_}[$i-1][$1-1]/eg for keys %extract;
		$outputs{$out} = 1;
	}
	my @outputs = keys %outputs;
	my $outcount = $#outputs;
	logAdd( "   Duplicates removed, items reduced from $count to $outcount" ) if $::debug and $count > $outcount;

	# Read in the items from the log for this source that are newer than maxage
	my $file = "$source.log";
	open OUTH, '<', $file;
	my $chopped = '';
	while( <OUTH> ) {
		m|^(.+?):(.+?):(.+)$|;
		my $date = $1;
		$chopped .= $_ if time() - $date < $::maxage;
	}
	close OUTH;

	# Append the new items to the chopped log content with date and a GUID
	for my $out ( @outputs ) {
		logAdd( "   \"$out\" >> \"$file\" " );
		my $guid  = strftime( '%Y%m%d', localtime );
		$guid .= '-';
		$guid .= chr( rand() < 0.72 ? int( rand( 26 ) + 65 ) : int( rand( 10 ) + 48 ) ) for 1 .. 5;
		my $date  = time();
		$chopped .= "$date:$guid:$out\n";
	}

	# Write the updated chopped content back to the log
	writeFile( $file, $chopped );
}
