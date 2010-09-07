<?php
/**
 * Handles registration, confirmation, payment and polling from mtconnect.exe instances
 * 
 * @author Aran Dunkley [http://www.organicdesign.co.nz/nad User:Nad]
 * @copyright © 2010 Aran Dunkley
 * 
 * Version 1.0 started on 2010-08-30
 */

$version = '1.0.2 (2010-09-07)';

$dir = dirname( __FILE__ );

switch( $_GET['action'] ) {

	case 'register':
	
		# Registration page
		?><html>
			<head></head>
			<body>
				This is the registration page...
			</body>
		</html><?php

	break;

	case 'comfirm':
	
		# Email confirmation
		?><html>
			<head></head>
			<body>
				This is the email confirmation page...
			</body>
		</html><?php

	break;

	case 'payment':
	
		# Payment page
		?><html>
			<head></head>
			<body>
				This is the payment page...
			</body>
		</html><?php
	
	break;

	case 'api':

		# Check if key valid and current or is the test key
		$key = $_GET['key'];
		$file = $key == "test" ? "test.log" : "production.log";

		# Connection from an mtconnect.exe instance
		$items = file_get_contents( "$dir/$file" );

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
