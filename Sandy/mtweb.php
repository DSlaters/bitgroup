<?php
/**
 * Handles registration, confirmation, payment and polling from mtconnect.exe instances
 * 
 * @author Aran Dunkley [http://www.organicdesign.co.nz/nad User:Nad]
 * @copyright © 2010 Aran Dunkley
 * 
 * Version 1.0 started on 2010-08-30
 */

$version = '1.1.2 (2010-11-24)';

$dir = dirname( __FILE__ );
$url = 'http://www.organicdesign.co.nz/files/mtweb.php';

$recipients = array( 'nad@localhost' );

$link = false;
$database = 'sandy';
$table = 'registrations';

$action = array_key_exists( 'action', $_GET ) ? $_GET['action'] : false;
$key = array_key_exists( 'key', $_GET ) ? $_GET['key'] : false;

switch( $action ) {

	# Registration page
	case 'register':

		# If form posted, create the registration entry
		if( array_key_exists( 'newkey', $_POST ) ) {
			dbRegister( $_POST );
			emailRegistration( $_POST );
		}

		# Otherwise render the registration form
		else {
			?><html>
				<head></head>
				<body>
					This is the registration page...
					<form action="<?php print $url; ?>?action=register" method="POST">
						<table>

							<tr>
								<td>Registration key:</td>
								<td>
									<input name="newkey" value="<?php print $key; ?>" /><br />
								</td>
							</tr>

							<tr>
								<td>Email address:</td>
								<td>
									<input name="email" /><br />
								</td>
							</tr>

							<tr>
								<td>Full name:</td>
								<td>
									<input name="name" value="<?php print $key; ?>" /><br />
								</td>
							</tr>

							<tr>
								<td>Currency:</td>
								<td>
									<select name="currency">
										<option>NZD</option>
										<option>USD</option>
										<option>EUR</option>
										<option>JPY</option>
										<option>CHF</option>
									</select>
								</td>
							</tr>

							<tr>
								<td></td>
								<td><input type="submit" value="Register" /></td>
							</tr>

						</table>
					</form>
				</body>
			</html><?php
		}

	break;

	# Email confirmation
	case 'comfirm':

		?><html>
			<head></head>
			<body>
				This is the email confirmation page...
			</body>
		</html><?php

	break;

	# Payment page
	case 'payment':

		?><html>
			<head></head>
			<body>
				Click the "checkout" button to set up the subscription for <?php print "$amount $currency"; ?> per month...
				<form name="_xclick" action="https://www.paypal.com/cgi-bin/webscr" method="post">
					<input type="hidden" name="cmd" value="_xclick-subscriptions">
					<input type="hidden" name="business" value="TWPVHY2Q8UC8W" />
					<input type="hidden" name="no_shipping" value="1">
					<input type="hidden" name="item_name" value="MTAlert subscription">
					<input type="hidden" name="currency_code" value="<?php print $currency; ?>">
					<input type="hidden" name="a3" value="<?php print $amount; ?>">
					<input type="hidden" name="p3" value="1">
					<input type="hidden" name="t3" value="M">
					<input type="hidden" name="src" value="1">
					<input type="hidden" name="sra" value="1">
					<input type="submit" value="Checkout" />
				</form>
			</body>
		</html><?php
	
	break;

	# Called by the mtconnect.exe instances
	case 'api':

		# Check if key valid and current or is the test key
		$file = $key == "test" ? "test.log" : "production.log";

		# Read items from the test or production log
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
				<ul>
					<li><a href="<?php print $url;?>?action=register">Registration page</a></li>
					<li><a href="<?php print $url;?>?action=payment">Payment page</a></li>
				</ul>
			</body>
		</html><?php
}

# Close the database if a connection was opened
if( $link ) mysql_close( $link );

# Connect to the DB and create the table if it doesn't exist
function dbConnect( $database, $table ) {
	global $link;

	# Read the DB access and bot name info from wikid.conf
	foreach( file( '/var/www/tools/wikid.conf' ) as $line ) {
		if ( preg_match( "|^\s*\\\$(wgDB.+?)\s*=\s*['\"](.+?)[\"']|m", $line, $m ) ) $$m[1] = $m[2];
	}

	# Connect to the server and select the database
	$link = mysql_connect( 'localhost', $wgDBuser, $wgDBpassword );
	mysql_select_db( $database, $link );

	# Create the table if it doesn't exist
	if( $res = mysql_query( "SELECT 1 FROM $table LIMIT 1", $link ) ) {
		mysql_free_result( $res );
	} else {
		$sql = "CREATE TABLE $table (id VARCHAR(32), email VARCHAR(64), name VARCHAR(64), currency VARCHAR(3), status VARCHAR(16), PRIMARY KEY (id));";
		$res = mysql_query( $sql, $link );
		mysql_free_result( $res );
	}

	return $link;
}

# Create a registration entry in the DB from a posted form
function dbRegister( $args ) {
	global $database, $table;
	$link = dbConnect( $database, $table );
}

# Email info about a registration to recipient list
function emailRegistration( $args ) {
	global $recipients;
	
	# Create message
	
	# Send message
}

?>
