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
require "/var/www/tools/wiki.pl";
require "/var/www/tools/wikid.conf";

$::cookies = HTTP::Cookies->new();
$::ua = LWP::UserAgent->new(
	cookie_jar => $::cookies,
	agent      => 'Mozilla/5.0 (Ubuntu; X11; Linux x86_64; rv:8.0) Gecko/20100101 Firefox/8.0',
	timeout    => 30,
);

# Log in to the crowdrating.org wiki
$::wiki = 'http://www.crowdrating.org/wiki/index.php';
wikiLogin( $::wiki, 'Server', $wikipass );

# Obtain the import items from the crowdrating.org wiki
my @rules = ();
if( $import_rules = wikiRawPage( $::wiki, 'import_rules' ) ) {
	@rules = $import_rules =~ /\{\{Import\s*(.+?)\s*\}\}/sg;
} else { die( 'Could not extract import rules from import_rules article' ) }

# Format the rules into a hash for the import routine
my $data = [];
for( @rules ) {
	my $id      = $1 if /^\s*\|\s*id\s*=\s*(.+?)\s*$/m;
	my $url     = $1 if /^\s*\|\s*url\s*=\s*(.+?)\s*$/m;
	my $pages   = $1 if /^\s*\|\s*pages\s*=\s*(.+?)\s*$/m;
	my $import  = $1 if /^\s*\|\s*import\s*=\s*(.+?)\s*$/m;
	my $reviews = $1 if /^\s*\|\s*reviews\s*=\s*(.+?)\s*$/m;
	push @$data, {
		id => $id,
		url => $url,
		pages => $pages,
		import => $import,
		reviews => $reviews
	};
}

# Loop through the search results for each data item
for my $search ( @$data ) {

	my $search_name    = $$search{id};
	my $search_url     = $$search{url};
	my $search_pages   = $$search{pages};
	my $search_import  = $$search{import};
	my $search_reviews = $$search{reviews};

	print "Search item: $search_name\n";

	for( 1 .. $search_pages ) {

		# Get the search page content
		my $search_html = 0;
		for( 1 .. 10 ) {
			my $res = $::ua->get( $search_url );
			$search_html = $res->content if $res->is_success and $res->content =~ m|<div id="srNum_\d+" class="number">\d+\.</div>|s;
			last if $search_html;
		}

		# Get books info from search page (note that cats with too many books may be a different format)
		if( $search_html ) {
			my @books = $search_html =~ m|<div id="srNum_\d+" class="number">(\d+)\.</div>.+?class="title" href="([^"]+/dp/([^"/]+?)/[^"]+)">([^<]+)|sg;
			for( my $i = 0; $i < $#books; $i += 4 ) {
				my $n = $books[$i];
				my $url = $books[$i + 1];
				my $asin = $books[$i + 2];
				my $title = $books[$i + 3];
				print "\t$asin \"$title\"\n";

				# convert ASIN to ISBN-13
				if( my $isbn = getISBN( $url ) ) {

					# Use ISBN-13 to get crowdrating
					my( $average, $reviews ) = calculateCrowdrating( $isbn, $title );

					# Store the data if valid
					if( $reviews ) {
						qx( echo "$search_name\t$n\t$asin\t$isbn\t$average\t$reviews\t$title" >> /var/www/tools/crowdrating.org/amazon-import.log );
					}

				}
			}
			print "\n\n";
		} else { sendError( "Failed on search page: $search_name" ) }

		# Get next page
		$search_url = $search_html =~ m|href="([^"]+)">Next »<| ? "http://www.amazon.com$1" : 0;
	}
}

# Get the ISBN-13 from the passed book URL
sub getISBN {
	my $url = shift;
	my $isbn = 0;
	for( 1 .. 10 ) {
		my $res = $ua->get( $url );
		$isbn = $1 if $res->is_success and $res->content =~ m|>ISBN-13:</b>\s+([0-9-]+)|;
		last if $isbn;
	}
	$isbn =~ s/-//;
	return $isbn;
}

# Create the book in the wiki if it doesn't already exist
sub addBook {
	$isbn = shift;
}

# Dummy send error - this is only used when updating wiki crowd-ratings
sub sendError{
	print "$error\n";
}
