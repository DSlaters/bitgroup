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
use strict;

$ver    = '0.0.1'; # 2010-08-30
$daemon = 'mtserver';

# Ensure CWD is in the dir containing this script
chdir $1 if realpath( $0 ) =~ m|^(.+)/|;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$log  = "$1.log";
require( "$1.conf" );
logAdd();
logAdd( "$::daemon-$::ver" );

# Run as a daemon (see daemonise.pl article for more details and references regarding perl daemons)
open STDIN, '/dev/null';
open STDOUT, ">>$log";
open STDERR, ">>$log";
defined ( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";
umask 0;
$0 = "$daemon ($ver)";

# Install the service into init.d and rc2-5.d if --install arg passed
if ( $ARGV[0] eq '--install' ) {
	writeFile( my $target = "/etc/init.d/$daemon", "#!/bin/sh\n/usr/bin/perl $dir/$daemon.pl\n" );
	symlink $target, "/etc/rc$_.d/S99$daemon" for 2..5;
	symlink "$dir/$daemon.pl", "/usr/bin/$daemon";
	chmod 0755, "/etc/init.d/$daemon";
	logAdd( "$daemon added to /etc/init.d and /usr/bin" );
}

# Remove the named service and exit
if ( $ARGV[0] eq '--remove' ) {
	unlink "/etc/rc$_.d/S99$daemon" for 2..5;
	unlink "/etc/init.d/$daemon.sh";
	logAdd( "$daemon.sh removed from /etc/init.d" );
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
	my %args = $::source{local};
	my $server = $args{ssl} ? Net::IMAP::Simple::SSL->new( $args{host} ) : Net::IMAP::Simple->new( $args{host} );
	if ( $server ) {
		if ( $server->login( $args{user}, $args{pass} ) > 0 ) {
			logAdd( "Logged \"$args{user}\" into IMAP server \"$args{host}\"" );
			my $i = $server->select( $args{path} or 'Inbox' );
			logAdd( "$i messages to scan" );
			while ( $i > 0 ) {
				if ( my $fh = $server->getfh( $i ) ) {
					sysread $fh, ( my $content ), $limit;
					close $fh;
					$server->delete( $i ) if processMessage( $content, $t );
				}
				$i--;
			}
		} else { logAdd( "Couldn't log \"$args{user}\" into $args{proto} server \"$args{host}\"" ) }
		$server->quit();
	} else { logAdd( "Couldn't connect to $args{proto} server \"$args{host}\"" ) }
}

