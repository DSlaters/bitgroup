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
use HTTP::Request;
use LWP::UserAgent;
#use Digest::MD5 qw( md5_hex );
use Cwd qw(realpath);
use strict;

$::ver = '0.0.9 (2010-09-01)';

# Ensure CWD is in the dir containing this script
chdir $1 if realpath( $0 ) =~ m|^(.+)/|;
$::dir         = $1;
$::daemon      = 'MTConnect';
$::description = 'Connect notification server to MT4 robots';
$::period      = 10;
$::last        = 0;
$::mtserver    = 'http://www.organicdesign.co.nz/files/mtweb.php';
$::output      = "$::dir/trigger\$1.txt";
$::debug       = 1;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::log  = "$1.log";

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


# Output an item to the email log file with timestamp
sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}


# Start-service callback: Set up non-blocking SMTP listener
sub svcStart {
	logAdd( "Service started successfully" );

	# Set up a global user agent for making HTTP requests as a browser
	$::ua = LWP::UserAgent->new(
		cookie_jar => {},
		agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
		from       => 'mtconnect@organicdesign.co.nz',
		timeout    => 5,
		max_size   => 100000
	);

	Win32::Daemon::State( SERVICE_RUNNING );
}


# Main service processing function
sub svcRunning {
	if( SERVICE_RUNNING == Win32::Daemon::State() ) {

		# Check if time to poll the server
		my $seconds = time();
		if( $seconds % $::period == 0 ) {
			if ( $::lastcheck != $seconds ) {
				my $thread = threads->new( \&checkServer );
				my $id = $thread->tid();
				logAdd( "Started thread with ID $id to check server..." );
			}
			$::lastcheck = $seconds;
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


# Check the passed email source for messages to process
sub checkServer {
	my $id = threads->tid();
	my $t  = "[Thread $id]";

	# This thread doesn't need to be rejoined on return
	threads->detach();

	# Check server with (if lastitem is zero, server will return items in last $::maxage)
	my $url = "$::mtserver?action=api&key=$::key&last=$::last";
	my $response = $::ua->get( $url );
	if( $response->is_success ) {

		my @items = split /\n/, $response->content;
		my $n = 1 + $#items;
		logAdd( "$t    $n item(s) returned from $url" ) if $::debug;

		# Loop through the returned items creating a trigger file for each
		for my $item ( @items ) {

			# Extract the info from the item line
			$item =~ m|^(.+?):(<.+?>):(.+)$|;
			my $date = $1;
			$::last = $2;
			logAdd($::last);
			$item = $3;

			# Find the next available filename
			my $file;
			my $j = 1;
			do {
				$file = $::output;
				$file =~ s/\$1/$j++/e;
			} while -e $file;

			# Write the output to the new file
			if( open OUTH, '>', $file ) {
				logAdd( "$t    Created: $file containing \"$item\"" );
				print OUTH $item;
				close OUTH;
			} else { logAdd( "$t    Can't create \"$file\" for writing!" ) }
		}
	}
}


