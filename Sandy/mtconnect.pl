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
use POSIX qw( strftime );
use Win32;
use Win32::Daemon;
use Win32::Perms;
use HTTP::Request;
use LWP::UserAgent;
use Cwd qw(realpath);
use strict;

$::ver = '1.2.4 (2010-09-12)';

# Ensure CWD is in the dir containing this script
chdir $1 if realpath( $0 ) =~ m|^(.+)[/\\]|;
$::dir         = $1;
$::daemon      = 'MTConnect';
$::description = 'Connect notification server to MT4 robots';
$::period      = 10;
$::last        = 0;
$::key         = 0;
$::mtserver    = 'http://www.organicdesign.co.nz/files/mtweb.php';
$::output      = "$::dir/trigger\$1.txt";
$::debug       = 1;

# Determine log file and config file
$0 =~ /^(.+)\..+?$/;
$::prog = $1;
$::prog =~ s/[-.0-9]+//g;
$::log  = "$::prog.log";

logAdd();
logAdd( "$::daemon-$::ver" );

# Install or remove the service if switch provided
&svcRemove if $ARGV[0] =~ /^(-r|--remove)$/i;
&svcInstall unless $ARGV[0] =~ /^--run$/i;

# Redirect STDOUT and STDERR to log file
open STDOUT, ">>$::log";
open STDERR, ">>$::log";
$| = 1;

# Read the last item ID if any
getLastItem();

# Read the key if any, or create if none
initKey();

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
			checkServer() if $::lastcheck != $seconds;
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

	# Stop existing instance if one running
	logAdd( "Stopping existing instance if any..." );
	qx( net stop $::daemon );

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
		#die;
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

	# Check server with (if lastitem is zero, server will return items in last $::maxage)
	my $url = "$::mtserver?action=api&key=$::key&last=$::last";
	my $response = $::ua->get( $url );
	if( $response->is_success ) {

		my @items = split /\n/, $response->content;
		my $n = 1 + $#items;
		logAdd( "$n item(s) returned from $url" ) if $::debug;

		# Loop through the returned items creating a trigger file for each
		for my $item ( @items ) {

			# Extract the info from the item line
			$item =~ m|^(.+?):(.+?):(.+)$|;
			my $date = $1;
			setLastItem( $2 );
			$item = $3;

			# Find the next available filename
			my $file;
			my $j = 1;
			do {
				$file = $::output;
				$file =~ s/\$1/$j++/e;
			} while -e $file;

			# Write the output to the new file and set to full access perms
			if( open OUTH, '>', $file ) {
				logAdd( "Created: $file containing \"$item\"" ) if $::debug;
				print OUTH $item;
				close OUTH;
				
				# Set full access permissions to the new trigger file
				if( my $perm = new Win32::Perms( $file, PERM_TYPE_NULL ) ) {
					$perm->Set();
				} else { logAdd( "Couldn't create the permissions for the new trigger file \"$file\"!" ) }
				
			} else { logAdd( "Can't create \"$file\" for writing!" ) }
		}
	}
}


# Remember last item and write to file
sub setLastItem {
	$::last = shift;
	if ( open FH,'>', "$::prog.lst" ) {
		print FH $::last;
		close FH;
		logAdd( "$::prog.lst updated to \"$::last\"" ) if $::debug;
	} else { logAdd( "Couldn't write last item ID!") }
}


# Retrieve last item from file
sub getLastItem {
	if ( open FH, '<', "$::prog.lst" ) {
		$::last = <FH>;
		close FH;
		logAdd( "Last ID updated to \"$::last\" from $::prog.lst" ) if $::debug;
	} else { logAdd( "Nothing read from $::prog.lst" ) if $::debug }
}

# Read the key if any, or create if none
sub initKey {
	my $file = "$::prog.key";
	if( -e $file ) {
		open KH, '<', $file;
		$::key = <KH>;
		chomp $::key;
		close KH;
		logAdd( "Key \"$::key\" imported" ) if $::debug;
	} else {
		if ( open KH,'>', $file ) {
			$::key = strftime( '%Y%m%d', localtime );
			$::key .= chr( rand() < 0.72 ? int( rand( 26 ) + 65 ) : int( rand( 10 ) + 48 ) ) for 1 .. 24;
			print KH $::key;
			close KH;
			logAdd( "No key file found, new key created: \"$::key\"" ) if $::debug;
		} else { logAdd( "Couldn't create key file!") }
	}
}
