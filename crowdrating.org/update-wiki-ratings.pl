#!/usr/bin/perl
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html
#
use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use URI::Escape;
require "/var/www/tools/crowdrating.org/crowdrating.pl";

$wiki = "http://$ARGV[0]/wiki/index.php";
$::startTime = localtime();
$::cookies = HTTP::Cookies->new();
$::ua = LWP::UserAgent->new(
	cookie_jar => $::cookies,
	agent      => 'Mozilla/5.0 (Ubuntu; X11; Linux x86_64; rv:8.0) Gecko/20100101 Firefox/8.0',
	timeout    => 30,
);

# Read the current list of books from the wiki
$res = $ua->get( "$wiki?action=getbooks" );
if( $res->is_success ) {

	# Loop through the books getting rating and updating book articles in the wiki
	%books = $res->content =~ /^(\d+):(.+?)$/gm;
	while( ( $isbn, $title ) = each %books ) {

		# Calculate the crowdrating by scraping different book sites
		my( $wa, $wt ) = calculateCrowdrating( $isbn, $title );

		# Send the updated rating for this book to the wiki
		$title =~ s/ /_/g;
		$title =~ s/([\W])/ "%" . uc( sprintf( "%2.2x", ord( $1 ) ) ) /eg;
		$res = $ua->get( "$wiki?action=setrating&isbn=$isbn&rating=$wa&reviews=$wt" );
		print "\n\t" . $res->content . "\n" if $res->is_success;

		sleep( 300 );
	}
}

sub sendError {
	$::errors++;
	$::valid = 0 unless $::valid == 1 and $::w0 > 0;
	my $err = shift;
	my $name = shift;
	my $isbn = shift;
	my $url = shift;
	my $x1 = shift;
	my $w1 = shift;
	my $src1 = shift;
	my $src2 = shift;
	my $errfile = '/tmp/wl.pl.err';
	my $subject = "Crowdrating Alert: problem with $name for ISBN $isbn";

	writeFile( "$::tmp/$name-$isbn.txt", $src1 );
	writeFile( "$::tmp/$name-$isbn-2.txt", $src2 );

	open FH,'>', $errfile;
	print FH "Problem: $err\n\n";
	print FH "Validation: This result is still valid based on previous data\n\n" if $::valid;
	print FH "Validation: This result is now invalid\n\n" unless $::valid;
	print FH "(rating,reviews) before -> after: ($::x0,$::w0) -> ($x1,$w1)\n\n";
	print FH "The review can be found here:\n$url\n\n";
	print FH "The source obtained:\n$::tmpurl/$name-$isbn.txt\n\n";
	print FH "Second source file:\n$::tmpurl/$name-$isbn-2.txt\n\n" if $src2;
	print FH "Job start time: $::startTime\n";
	print FH "Current time: " . ( localtime() ) . "\n";
	print FH "Books processed so far: $::books\n";
	print FH "Valid results so far: $::valids\n";
	print FH "Invalid results so far: $::invalids\n";
	print FH "Errors encountered so far: $::errors\n";
	close FH;

	qx( mail -s "$subject" aran\@organicdesign.co.nz < $errfile );
	qx( rm -f $errfile );

	print "\t\t\tRating result invalid, book not updated.\n\t\t\t\t$subject\n\t\t\t\t$err\n\n";
}

sub writeFile {
	my $file = shift;
	if ( open FH,'>', $file ) {
		binmode FH;
		print FH shift;
		close FH;
		return $file;
	}
}
