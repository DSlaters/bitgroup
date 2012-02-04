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
# NOTES:
# stores and caches the data
# then when run, if no cache, does a full search sorted by rating
#                if cache exists, searches by publication date and finds new books since last search
#
#
use HTTP::Request;
use HTTP::Cookies;
use LWP::UserAgent;
use URI::Escape;
require "crowdrating.pl";

$::cookies = HTTP::Cookies->new();
$::ua = LWP::UserAgent->new(
	cookie_jar => $::cookies,
	agent      => 'Mozilla/5.0 (Ubuntu; X11; Linux x86_64; rv:8.0) Gecko/20100101 Firefox/8.0',
	timeout    => 30,
);

# Loop through the categories we want to import from
for my $cat ( 2675 ) {

	print "Category: $cat\n";

	# Get cat page
	if( my $catlink = getCategoryPage( $cat ) ) {

		do {

			# Get the catlinks page content
			my $page = 0;
			my $catpage = 0;
			for( 1 .. 10 ) {
				$res = $::ua->get( $catlink );
				$catpage = $res->content if $res->is_success and $res->content =~ m|<div id="srNum_\d+" class="number">\d+\.</div>|s;
				last if $catpage;
			}

			# Get ISBN-10's from cat page (note that cats with too many books are a different format):
			if( $catpage ) {
				my @isbns = $catpage =~ m|<div id="srNum_\d+" class="number">(\d+)\.</div>.+?class="title" href="[^"]+/dp/([^"/]+?)/[^"]+">([^<]+)|sg;
				for( my $i = 0; $i < $#isbns; $i+=3 ) {
					my $n = $isbns[$i];
					my $isbn = $isbns[$i+1];
					my $title = $isbns[$i+2];
					print "\t$n" . ". $isbn \"$title\"\n";

					# convert ISBN-10 to ISBN-13
					if( my $isbn = isbn10to13( $isbn ) ) {

						# Use EAN to get crowdrating
						my( $average, $reviews ) = calculateCrowdrating( $isbn, $title );

						# Store the data if valid
						if( $reviews ) {
							qx( echo "$cat, $n, $isbn, $average, $reviews, \\"$title\\"" >> /var/www/tools/crowdrating.org/amazon-import.log );
						}

					}
				}
				print "\n\n";
			}

			# Get next cat page
			$catlink = $catpage =~ m|href="([^"]+)">Next »<| ? "http://www.amazon.com$1" : 0;
		} while( $catlink );
	}
}

# Get the ISBN, rating and number of reviews from the passed book URL
sub getBookInfo {
	$res = $ua->get( shift );
	if( $res->is_success ) {
		$isbn = $1 if $res->content =~ m|>ISBN-13:</b>\s+([0-9-]+)|;
		$isbn =~ s/-//;
		$rating = $1 if $res->content =~ m|>([0-9.]+) out of \d+ stars<|;
		$reviews = $1 if $res->content =~ m|>([0-9,]+) customer reviews?<|;
		return( $isbn, $rating, $reviews );
	}
}

# Return the link for a category page given a category number
sub getCategoryPage {
	my $cat = shift;
	my $link = 0;

	# Get link for first book in bestsellers list for this cat
	my $book = 0;
	for( 1 .. 10 ) {
		$res = $::ua->get( "http://www.amazon.com/gp/bestsellers/books/$cat" );
		$book = $1 if $res->is_success and $res->content =~ m|<span class="zg_rankNumber">1.</span>.+?href="\s*(.+?)\s*">|s;
		last if $book;
	}

	# Extract the link for our category from the book page
	if( $book ) {

		# Get the category link from the section in the book page
		for( 1 .. 10 ) {
			$res = $::ua->get( $book );
			if( $res->is_success and $res->content =~ m|<h2>Look for Similar Items by Category</h2>.+?<ul>\s*(.+?)\s*</ul>|s ) {
				$link = $1 if $1 =~ m|href="([^"]+node=$cat)"|;
				last if $link;
			}
		}
	}

	$link =~ s|&amp;|&|g;
	return 'http://www.amazon.com' . $link;
}

# Create the book in the wiki if it doesn't already exist
sub addBook {
	$isbn = shift;
}

# Use LibraryThing API to convert ISBN-10 to ISBN-13
# TODO: use amazon if library thing doesn't have the API
sub isbn10to13 {
	my $isbn = shift;
	$res = $::ua->get( "http://www.librarything.com/isbncheck.php?isbn=$isbn" );
	$isbn = 0;
	$isbn = $1 if $res->is_success and $res->content =~ m|<isbn13>(.+?)</isbn13>|;
	return $isbn;
}

# Dummy send error - this is only used when updating wiki crowd-ratings
sub sendError{
}
