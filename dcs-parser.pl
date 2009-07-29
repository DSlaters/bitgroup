#!/usr/bin/perl
require('/var/www/tools/wiki.pl');

$dir  = '/var/www/dcs';
$log  = "$dir.log";
$wiki = 'http://dev.debtcompliance.com/wiki/index.php';
$user = 'Nad';
$pass = 'yN$ger0';

wikiLogin( $wiki, $user, $pass ) or die "Couldn't log into wiki!";

$line = 1;
for $file ( glob "$dir/*" ) {

	print "Processing \"$file\"";
	logAdd( "Processing \"$file\"" );
	open INPUT, '<', $_ or die "Could not open input file '$file'!";

	$title = '';
	$text  = '';
	for ( <INPUT> ) {
		
		if ( /^>>>\s*(.+)\s*<<<\s*/ ) {
			
			if ( $text ) {
				if ( $title ) {
					wikiEdit( $wiki, $title, $text, "Content imported from $file" );
				}
				else {
					logAdd( "Warning: Content preceeding first title marker ignored" );
				}
			}

			$title = $1;
			
		}
		elsif ( /^>>>/ or /<<<\s*$/ ) {
			logAdd( "Error: badly formed title markup on line $line" );
		}
		else {
			$text .= $_;
		}
		
		
	$line++;
	}
	
	close INPUT;
	 
}
