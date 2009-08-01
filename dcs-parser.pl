#!/usr/bin/perl
require('/var/www/tools/wiki.pl');

$dir  = '/var/www/dcs';
$log  = "$dir.log";
$wiki = 'http://dev.debtcompliance.com/wiki/index.php';
$user = 'Nad';
$pass = 'yN$ger0';

wikiLogin( $wiki, $user, $pass ) or die "Couldn't log into wiki!";

sub doPage {
	if ( $text ) {
		if ( $pass and $title ) {
			wikiEdit( $wiki, $title, $text, "Content imported from $file" );
			sleep 1 if $changed; # delay to give time for the bot to update terms links
		}
		else {
			logAdd( "Warning: Content preceeding first title marker ignored" );
		}
		$text = '';
	}
}

for $pass ( 0..1 ) {

	$line = 1;
	for $file ( glob "$dir/*" ) {

		$comment = "PASS-" . ( $pass+1 ) . ": Processing \"$file\"";
		print "$comment\n";
		logAdd( $comment );
		open INPUT, '<', $file or die "Could not open input file '$file'!";

		$title = '';
		$text  = '';
		for ( <INPUT> ) {

			if ( /^>>>\s*(.+)\s*<<<\s*/ ) {
				&doPage;
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
		&doPage;
	}
}
