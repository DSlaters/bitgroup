#!/usr/bin/perl
#
# Synchronise an article from one wiki to all others in the DCS wikia
#
# Author: http://www.organicdesign.co.nz/nad
#
use HTTP::Request;
use LWP::UserAgent;

# Set defaults
$domain = "debtcompliance.com";
$lsfile = "/var/www/wikis/dc2/LocalSettings.php";

# Read in the LocalSettings.php file for the DCS wikia
open LS, '<', $lsfile or die "Could not read LocalSettings.php for DCS wikia!";
sysread LS, $ls, -s $lsfile;
close LS;

# Extract a list of wikis from it
@wikis = ( $ls =~ /^\s*\$wgShortName\s*=\s*"(.+?)";\s*$/gm );

# Set up a global client for making HTTP requests as a browser
$ua = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'runwikijobs.pl@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 1024
);

# Loop through all wikis requesting the main page of each
for $wiki ( @wikis ) {
	$url = "https://$wiki.$domain/wiki/index.php?title=Special:Userlogin";
	print "$url\n";
	$ua->get( $url );
}

0;
