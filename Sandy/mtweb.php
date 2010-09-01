<?php
/**
 * Handles registration, confirmation, payment and polling from mtconnect.exe instances
 * 
 * @author Aran Dunkley [http://www.organicdesign.co.nz/nad User:Nad]
 * @copyright © 2010 Aran Dunkley
 * 
 * Version 1.0 started on 2010-08-30
 */

$version = '1.0.1 (2010-09-02)';
$maxage  = 900;
$file    = '/var/www/tools/Sandy/mtserver.out';

switch( $_GET['action'] ) {

	case 'register':
	
		# Registration page
		?><html>
			<head></head>
			<body>
				This is the home page...
			</body>
		</html><?php

	break;

	case 'comfirm':
	
		# Email confirmation
		?><html>
			<head></head>
			<body>
				This is the home page...
			</body>
		</html><?php

	break;

	case 'payment':
	
		# Payment page
		?><html>
			<head></head>
			<body>
				This is the home page...
			</body>
		</html><?php
	
	break;

	case 'api':
	
		# Connection from an mtconnect.exe instance
		$items = file_get_contents( $file );

		# - check if key valid and current
		$key = $_GET['key'];
		#if( !$valid )  die( "Error 1: supplied key is invalid." );
		#if( $expired ) die( "Error 2: supplied key has expired." );

		# return items since last
		if( $last = $_GET['last'] ) {

			# Get the items since the last one
			$tmp = '';
			$found = false;
			foreach( explode( "\n", $items ) as $line ) {
				preg_match( "|^(.+?):(.+?):(.+)$|", $line, $m );
				list( ,$date, $guid, $item ) = $m;
				if( $found ) $tmp .= "$line\n";
				if( $guid == $last) $found = true;
			}
			if( $found ) $items = $tmp;

		}

		print $items;

	break;

	default:

		# Home page
		?><html>
			<head></head>
			<body>
				This is the home page...
			</body>
		</html><?php
}

?>
