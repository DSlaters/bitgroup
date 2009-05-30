#!/usr/bin/perl

$filter = '# Exim filter
if
   $h_X-Spam-Status: CONTAINS "Yes"
	  or
   "${if def:h_X-Spam-Flag {def}{undef}}" is "def"
then
   save $home/Maildir/.Junk\40E-mail/
   finish
endif';

for ( glob "/home/*" ) {
	$file = "$_/.forward";
	if ( ! -e $file ) {
		s|^.+/||;
		qx( echo '$filter' > $file );
		qx( chown $_:$_ $file );
	}	
}

