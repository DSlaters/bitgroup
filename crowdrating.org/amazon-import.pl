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

	# Get first page of bestsellers in this category
	$res = $ua->get( "http://www.amazon.com/gp/bestsellers/books/$_" );
	if( $res->is_success ) {

		# Get book info from first page
		#extractLinks( $res->content );
		
		# Get book info from subsequent pages listed at bottom of first page
		@pages = $res->content =~ m|href="(.+?)">\d+-\d+</a>|g;
		$page = 1;
		for( @pages ) {
			print "Page $page\n";
			$res = $ua->get( $_ );
			extractLinks( $res->content ) if $res->is_success;
			$page++;
		}

	}
}

# Extract the book links from passed HTML and get ISBN and rating for each book
sub extractLinks {
	$html = shift;
	@links = $html =~ m|<div class="zg_itemInfo".+?href="(/.+?)"|sg;
	for( @links ) {
		( $isbn, $rating, $reviews ) = getBookInfo( "http://www.amazon.com$_" );
		if( $isbn ) {
			print "$isbn ($rating / $reviews)\n";
			addBook( $isbn ) if $rating > 3.5 and $reviews > 5;
		}
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

# Create the book in the wiki if it doesn't already exist
sub addBook {
	$isbn = shift;
}

# Dummy send error - this is only used when updating wiki crowd-ratings
sub sendError{
}
