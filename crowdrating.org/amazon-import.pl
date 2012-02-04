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
for ( 3, 2675 ) {

	print "Category: $_\n";

	# Get cat page
	if( $link = getCategoryPage( $_ ) ) {

		# http://www.amazon.com/Management-Leadership-Business-Investing-Books/b/ref=dp_brlad_entry?ie=UTF8&node=2675

		# Get books from page:
		# <div id="srNum_0" class="number">1.</div>
		#   <div class="image">
		#   <a href="http://www.amazon.com/7-Habits-Highly-Effective-People/dp/0671315285/ref=sr_1_1?s=books&ie=UTF8&qid=1328298298&sr=1-1">

		# convert ISBN to EAN
		# http://www.librarything.com/isbncheck.php?isbn=0385517823
		# (use amazon if library thing doesn't have the API)

		# Use EAN to get crowdrating

		# Store the data

		# Get next cat page
		# href="/s/ref=sr_pg_2?rh=n%3A283155%2Cn%3A%211000%2Cn%3A3%2Cn%3A2675&page=2&ie=UTF8&qid=1328299928">Next »<

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
	for( 1 .. 5 ) {
		$res = $::ua->get( "http://www.amazon.com/gp/bestsellers/books/$cat" );
		$book = $1 if $res->is_success and $res->content =~ m|<span class="zg_rankNumber">1.</span>.+?href="\s*(.+?)\s*">|s;
		last if $book;
	}

	# Extract the link for our category from the book page
	if( $book ) {

		# Get the category link from the section in the book page
		for( 1 .. 5 ) {
			$res = $::ua->get( $book );
			if( $res->is_success and $res->content =~ m|<h2>Look for Similar Items by Category</h2>.+?<ul>\s*(.+?)\s*</ul>|s ) {
				$link = $1 if $1 =~ m|href="([^"]+node=$cat)"|;
				$link =~ s|&amp;|&|g;
				last if $link;
			}
		}
	}

print $link;
exit;

	return $link;
}

# Create the book in the wiki if it doesn't already exist
sub addBook {
	$isbn = shift;
}

# Dummy send error - this is only used when updating wiki crowd-ratings
sub sendError{
}
