<?php
/**
 * Handles registration, confirmation, payment and polling from mtconnect.exe instances
 * 
 * @author Aran Dunkley [http://www.organicdesign.co.nz/nad User:Nad]
 * @copyright © 2010 Aran Dunkley
 * 
 * Version 1.0 started on 2010-08-30
 */

$version = '1.0.0 (2010-08-30)';
$maxage  = 900;

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
		$items = '';
		
		# - check if key valid and current
		$key = $_GET['key'];
		if( !$valid )  die( "Error 1: supplied key is invalid." );
		if( $expired ) die( "Error 2: supplied key has expired." );

		# return items since last
		if( $last = $_GET['last'] ) {

			# Get the items since the last one

		} else {

			# Get the items newer than $maxage

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
