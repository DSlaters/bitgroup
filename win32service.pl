#!/usr/bin/perl
use Win32;
use Win32::Daemon;
use Net::POP3;

our $daemon = 'PerlService';
our $description = "$daemon is a test of Perl's Win32 service functionality";

# Install or remove the service if switch provided
&svcInstall if $ARGV[0] =~ /^(-i|--install)$/i;
&svcRemove if $ARGV[0] =~ /^(-r|--remove)$/i;

# Redirect STDOUT and STDERR to log file
my ( $cwd,$bn,$ext ) = ( Win32::GetFullPathName( $0 ) =~ /^(.*\\)(.*)\.(.*)$/ )[0..2] ;
my $log = "$cwd$bn.log"; 
open( STDOUT, ">> $log" ) or die "Couldn't open $log for appending: $!\n";
open( STDERR, ">&STDOUT" );

# Autoflush, no buffering
$| = 1;

# Register the events which the service responds to
Win32::Daemon::RegisterCallbacks( {
	start    => \&svcStart,
	running  => \&svcRunning,
	stop     => \&svcStop,
	pause    => \&svcPause,
	continue => \&svcContinue
} );

# Start the service
Win32::Daemon::StartService( 0, 1000 );
close STDERR;
close STDOUT;


# Main service processing function
sub svcRunning {
	if ( SERVICE_RUNNING == Win32::Daemon::State() ) {
		print "Hello!\n";
	}
}	

sub svcStart {
	print "Starting...\n";
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub svcPause {
	print "Pausing...\n";
	Win32::Daemon::State( SERVICE_PAUSED );
}

sub svcContinue {
	print "Continuing...\n";
	Win32::Daemon::State( SERVICE_RUNNING );
}

sub svcStop {
	print "Stopping...\n";
	Win32::Daemon::State( SERVICE_STOPPED );
	Win32::Daemon::StopService();
}

# Install the service
sub svcInstall {
	my $fn = Win32::GetFullPathName( $0 );
	my ( $cwd, $bn, $ext ) = ( $fn =~ /^(.*\\)(.*)\.(.*)$/ ) [0..2] ;

	# Parameters when called as a .pl
	if ( $ext eq "pl" ) {
		$path = "\"$^X\"";
		my $inc = ( $cwd =~ /^(.*?)[\\]?$/ )[0];
		$parameters = "-I \"$inc\" \"$fn\"";
	}
	
	# Parameters when called as an exe
	elsif ( $ext eq "exe" ) {
		$path = "\"$fn\"";
		$parameters = "";
	}

	# The CreateService parameters
	my %svcInfo = (
		name         => $daemon,
		display      => $daemon,
		path         => $path,
		description  => $description,
		parameters   => $parameters
	);

	# Install the service
	if ( Win32::Daemon::CreateService( \%svcInfo ) ) {
		print "Service installed successfully\n";
	} else {
		die "Failed to install service";
	}

	exit;
}

# Uninstall the service
sub svcRemove {
	if ( Win32::Daemon::DeleteService( $daemon ) ) {
		print "Service uninstalled successfully\n";
	} else {
		die "Failed to uninstall service!";
	}

	exit;
}

