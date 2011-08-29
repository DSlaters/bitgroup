#!/usr/bin/perl -w
#
# Brings up random portuguese lessons in dialog boxes randomly
#
# Should be run from crontab every minute, e.g. with the following crontab entry
# */1 * * * * user env DISPLAY=:0.0 /var/www/tools/portuguese.pl
#
# Requires Debian packages perl-tk, libimage-size-perl, libmath-random-perl
use Encode qw(encode decode);
use Tk;
use Tk::DialogBox;
use Tk::widgets qw/JPEG PNG/;
use Image::Size;
use Math::Random;

# Location of sentences.txt and the Pictures directory
$lessons = "/home/nad/Contacts/Beth/Lessons";

# Exit if an instance is already already running
exit 0 if qx( ps aux | grep portuguese-running | grep -v grep );

# Mark process as running and wait for 1 to 10 minutes
$t = int( 60 + random_uniform() * 540 );
$0 = "portuguese-running ($t seconds)";
sleep( $t );

# Read the lessons in from the sentences.txt file containing lessons each of format:
# - one line for english sentence,
# - next for portuguese sentence,
# - an optional line for image filename
# - an empty line to separate from the next lesson
open FH, '<', "$lessons/sentences.txt";
$i = 0;
@lessons = ();
for( <FH> ) {
	chomp;
	if( /^.+$/ ) {
		push @lessons, $_;
		$i++;
	} else {
		push @lessons, "" if $i < 3;
		$i = 0;
	}
}
close FH;

# Pick a random lesson from the probability-biased list
$n = ( 1 + $#lessons ) / 3;
$lesson = 3 * int( 0.5 + $n * ( 1 - random_uniform() * random_uniform() ) );

# Set up tk main window
$mw = MainWindow->new;
$mw->withdraw();

# Load image if any and make it 150px wide
( $q, $a ) = ( 0, 1 );
if( $img = $lessons[$lesson + 2] ) {
	$file = "$lessons/Pictures/$img";
	($w, $k) = imgsize( $file );
	$k = $w / 150;
	$image = $mw->Photo( -file => $file );
	$resized = $mw->Photo( 'resized' );
	$resized->copy( $image, -subsample => $k, $k );
} else { ( $q, $a ) = ( 1, 0 ) if random_uniform() < 0.5 }

# Display the question dialog and wait for OK
%args = (
	-title   => "Question",
	-message => decode( "UTF-8", $lessons[$lesson + $q] ),
	-buttons => [ "Ok" ]
);
$args{-image} = $resized if defined $resized;
$mw->messageBox( %args );

# Display the answre dialog and wait for OK
$mw->messageBox(
	-title   => "Answer",
	-message => decode( "UTF-8", $lessons[$lesson + $a] ),
	-buttons => [ "Ok" ]
);

exit 0;


