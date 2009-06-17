#!/usr/bin/perl

for ( glob "/home/*" ) {
	$folder = "$_/Maildir/.Not\\ Junk";
	if ( ! -d $folder ) {
		s|^.+/||;
		qx( mkdir $folder );
		qx( chown $_:$_ $folder );
	}	
}

