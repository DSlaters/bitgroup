#!/usr/bin/perl -w
use Tk;
use Tk::DialogBox;
use Encode qw(encode decode);

# Time to wait before displaying lesson
$t = int( 60 + rand( 600 ) );

# Run from crontab every minute
# e.g. */1 * * * * root /var/www/tools/portuguese.pl

# Exit if already running
exit 0 if qx( ps aux | grep portuguese-running | grep -v grep );
$0 = "portuguese-running ($t seconds)";

# Read the list from the file
open FH, '<', "$0.txt";
push @lessons, $_ for grep /^.+/, <FH>;
close FH;

# Wait for a random time
sleep( $t );

# Pick a lesson from the list
$n = int( rand( 0.5 + $#lessons / 2 ) ) * 2;
( $q, $a ) = rand() < 0.5 ? ( 0, 1 ) : ( 1, 0 );

$d = MainWindow->new;
$d->withdraw();

# Display the question dialog
$d->messageBox(
	-title   => "Question",
	-message => decode( "UTF-8", $lessons[$n + $q] ),
	-buttons => [ "Ok" ]
);

# Display the answre dialog
$d->messageBox(
	-title   => "Answer",
	-message => decode( "UTF-8", $lessons[$n + $a] ),
	-buttons => [ "Ok" ]
);

exit 0;
