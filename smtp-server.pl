#!/usr/bin/perl
#
# Copyright (C) 2010 Aran Dunkley
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
use attributes;
use threads;
use threads::shared;
use Win32;
use Win32::Daemon;
use Net::SMTP::Server;
use Net::SMTP::Server::Client;
use Net::IMAP::Simple::SSL;
use Net::POP3;
use Cwd qw(realpath);
use strict;
$::ver = '2.6.0 (2010-08-11)';

# Ensure CWD is in the dir containing this script
chdir $1 if realpath( $0 ) =~ m|^(.+)/|;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::log  = "$1.log";
require( "$1.cfg.pl" );
logAdd();
logAdd( "$::daemon-$::ver" );

# Install or remove the service if switch provided
&svcRemove if $ARGV[0] =~ /^(-r|--remove)$/i;
&svcInstall unless $ARGV[0] =~ /^--run$/i;

# Redirect STDOUT and STDERR to log file
open STDOUT, ">>$::log";
open STDERR, ">>$::log";
$| = 1;

# Shared queue of open threads
our @queue:shared = ();

# Register the events which the service responds to
Win32::Daemon::RegisterCallbacks( {
	start    => \&svcStart,
	running  => \&svcRunning,
	stop     => \&svcStop,
	pause    => \&svcPause,
	continue => \&svcContinue
} );

# Start the service
logAdd( "Starting service..." );
Win32::Daemon::StartService( 0, 250 );
close STDERR;
close STDOUT;


# Start-service callback: Set up non-blocking SMTP listener
sub svcStart {
	logAdd( "Service started successfully" );
	$::server = new Net::SMTP::Server( '127.0.0.1', $::port )
		or logAdd( "Unable to start SMTP server on port $::port: $!" ) && die;
	$::server->{SOCK}->blocking( 0 )
		or logAdd( "Unable to set socket to non-blocking mode: $!" );
	$::server->{SOCK}->timeout( 0 );
	logAdd( "SMTP server listening on port $::port" );
	Win32::Daemon::State( SERVICE_RUNNING );
}


# Main service processing function
sub svcRunning {
	if( SERVICE_RUNNING == Win32::Daemon::State() ) {
		while( my $conn = $::server->accept() ) {
			if( my $client = new Net::SMTP::Server::Client( $conn ) ) {

				# Start a new message-processing thread
				my $thread = threads->new( \&processMessage, $client );
				my $id = $thread->tid();
				logAdd( "Started message-processor thread with ID $id" );
				
				# Push the new thread's ID onto the queue
				push @queue, $id;
				logAdd( 'Queue: ' . join( ',', @queue ) ) if $::debug;

			} else { logAdd( "Unable to handle incoming SMTP connection: $!" ) }
		}
	}
}


# Install the service
sub svcInstall {
	my $fn = Win32::GetFullPathName( $0 );
	my ( $cwd, $bn, $ext ) = ( $fn =~ /^(.*\\)(.*)\.(.*)$/ ) [0..2] ;
	my $path;
	my $parameters;

	# Parameters when called as a .pl
	if ( $ext eq "pl" ) {
		$path = "\"$^X\"";
		my $inc = ( $cwd =~ /^(.*?)[\\]?$/ )[0];
		$parameters = "-I \"$inc\" \"$fn\" --run";
	}
	
	# Parameters when called as an exe
	elsif ( $ext eq "exe" ) {
		$path = "\"$fn\"";
		$parameters = "--run";
	}

	# The CreateService parameters
	my %svcInfo = (
		name         => $::daemon,
		display      => $::daemon,
		path         => $path,
		description  => $::description,
		parameters   => $parameters
	);

	# Install the service
	if ( Win32::Daemon::CreateService( \%svcInfo ) ) {
		logAdd( "Service installed successfully" );
	} else {
		my $err = svcGetError();
		logAdd( "Failed to install service! ($err)" );
		die;
	}
	
	logAdd( "Starting service $::daemon..." );
	qx( net start $::daemon );
	exit();
}


# Remove the service
sub svcRemove {
	if ( Win32::Daemon::DeleteService( "", $::daemon ) ) {
		logAdd( "Service removed successfully" );
	} else {
		my $err = svcGetError();
		logAdd( "Failed to remove service! ($err)" );
		die;
	}
	logAdd( "Exiting." );
	exit;
}


# General service management callbacks
sub svcPause {
	logAdd( "Service paused" );
	Win32::Daemon::State( SERVICE_PAUSED );
}
sub svcContinue {
	logAdd( "Service continuing" );
	Win32::Daemon::State( SERVICE_RUNNING );
}
sub svcStop {
	logAdd( "Service stopping" );
	Win32::Daemon::State( SERVICE_STOPPED );
	Win32::Daemon::StopService();
}

sub svcGetError {
	return( Win32::FormatMessage( Win32::Daemon::GetLastError() ) );
}

# Process a message
# - match content against rules
# - if match is positive, format the result and write to file
sub processMessage {
	my $client = shift;
	my $id     = threads->tid();
	my $t      = "[Thread $id]";

	# This thread doesn't need to be rejoined on return
	threads->detach();

	# Give other threads time until this thread is at the front of the queue
	while( $queue[0] != $id ) {
		logAdd( "$t Waiting. Queue: " . join( ',', @queue ) ) if $::debug;
		threads->yield();
	}

	# Process the stream
	if ( $client->process ) {
	
		# Hack to cater for the multiple messages problem
		my %content  = ( $client->{MSG} =~ /(from:.+?)(?=(from:|$))/sig );
		my @messages = keys %content;
		logAdd( "$t Warning: " . ( 1 + $#messages ) . " messages have arrived as one, but have now been separated out" ) if $#messages > 0;
		for my $content ( @messages ) {

			# Extract useful information from the content
			my %message = ();
			$message{content} = $1 if $content =~ /\r?\n\r?\n\s*(.+?)\s*$/s;
			$message{id}      = $1 if $content =~ /^message-id:\s*(.+?)\s*$/mi;
			$message{date}    = $1 if $content =~ /^date:\s*(.+?)\s*$/mi;
			$message{to}      = $1 if $content =~ /^to:\s*(.+?)\s*$/mi;
			$message{from}    = $1 if $content =~ /^from:\s*(.+?)\s*$/mi;
			$message{subject} = $1 if $content =~ /^subject:\s*(.+?)\s*$/im;

			if( $::debug ) {
				logAdd( "$t Message received from $message{from}" );
				logAdd( "$t    To: $message{to}" );
				logAdd( "$t    Subject: $message{subject}" );
				logAdd( "$t    Content: $message{content}" );
			}

			# Apply the matching rules to the message and keep the captures for building the output
			my %extract = ();
			my %rules   = ();
			my $match   = 0;
			for my $k ( keys %$::ruleset ) {
				logAdd( "$t    Ruleset: $k" ) if $::debug;
				%rules = %{$$::ruleset{$k}};
				$match = 1;
				for my $field ( keys %{$rules{rules}} ) {
					my $pattern = $rules{rules}{$field};
					logAdd( "$t       Rule: $field => $pattern" ) if $::debug;
					$match = 0 unless defined $message{$field} and $message{$field} =~ /$pattern/sm;
					$extract{$field} = [ 0, $1, $2, $3, $4, $5, $6, $7, $8, $9 ];
					logAdd( "$t          Match failed!" ) unless $match or not $::debug;
					logAdd( "$t          Match!" ) if $match and $::debug;
				}
				last if $match;
			}

			if( $match ) {

				# Build the output
				my $out = $rules{format};
				$out =~ s/\$$_(\d)/$extract{$_}[$1]/eg for keys %extract;
				logAdd( "$t    Output: $out" ) if $::debug;

				# Write the output
				my $file = $rules{file};
				if( $file =~ /\$1/ ) {
					
					# Find the next available filename
					my $i = 1;
					do {
						$file = $rules{file};
						$file =~ s/\$1/$i++/e;
					} while -e $file;
							
					# Write the output to the new file
					if( open OUTH, '>', $file ) {
						logAdd( "$t    Created: $file" );
						print OUTH $out;
						close OUTH;
					} else { logAdd( "$t    Can't create \"$file\" for writing!" ) }

				} else {

					# Append the output to the new or existing file
					if( open OUTH, '>>', $file ) {
						logAdd( "$t    Appended: $file" );
						print OUTH $out;
						close OUTH;
					} else { logAdd( "$t    Can't open \"$file\" for appending!" ) }
				}
			}
		}
	}

	# Remove this thread's ID from the head of the queue
	shift @queue;
	logAdd( "$t Finished." );
	logAdd( "Queue: " . join( ',', @queue ) ) if $::debug;
	
}


# Output an item to the email log file with timestamp
sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}
