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
$::books = 0;
$::valids = 0;
$::invalids = 0;
$::errors = 0;
$::tmp = '/var/www/wikis/od/files/temp';
$::tmpurl = 'http://www.organicdesign.co.nz/files/temp';
$::cache = '/var/www/tools/crowdrating.org/cache';

sub calculateCrowdrating {
	my $isbn = shift;
	my $title = shift;

	print "\nCalculating crowdrating for ISBN $isbn ($title):\n";
	my $attempts = 3;

	# Get info from amazon.com from $isbn and update $isbn to ISBN13 format if not already
	my $url1 = "http://www.amazon.com/s/ref=nb_sb_noss?url=search-alias%3Dstripbooks&field-keywords=$isbn";
	my $x1 = 0;
	my $w1 = 0;
	my $src1 = 'No data';
	my $src1b = 'No data';
	for( 1 .. $attempts ) {
		my $res = $ua->get( $url1 );
		if( $res->is_success and $res->content =~ m|>1.<.+?<a href="(.+?)">|s ) {
			$src1 = $res->content;
			sleep( 5 );
			$res = $ua->get( $1 );
			$src1b = "Source URL: $1\n\n";
			if( $res->is_success ) {
				$src1b .= $res->content;
				$isbn = $1 if $res->content =~ m|>ISBN-13:</b>\s+([0-9-]+)|;
				$isbn =~ s/-//;
				$x1 = $1 if $res->content =~ m|>([0-9.]+) out of \d+ stars<|;
				$w1 = $1 if $res->content =~ m|>(\d+) customer reviews?<|;
				print "\n\tAmazon:\n\t\tRating:  $x1\n\t\tReviews: $w1\n";
			} else { $src1b .= "Response: " . $res->status_line }
		}
		last if $w1 > 0;
		sleep( 5 );
	}

	# Get info from Google books
	my $url2 = "http://books.google.com/books?q=$isbn";
	my $x2 = 0;
	my $w2 = 0;
	my $src2 = 'No data';
	my $src2b = 'No data';
	if ( 0 ) {
		for( 1 .. $attempts ) {
			my $res = $ua->get( $url2 );
			$src2 = $res->content;
			if( $res->is_success and $res->content =~ m|<a class="primary" href="(.+?)">| ) {
				sleep( 5 );
				$res = $ua->get( $1 );
				$src2b = "Source URL: $1\n\n";
				if( $res->is_success and $res->content =~ m|>User ratings<.+?>5 stars<.+?>(\d+)<.+?>4 stars<.+?>(\d+)<.+?>3 stars<.+?>(\d+)<.+?>2 stars<.+?>(\d+)<.+?>1 star<.+?>(\d+)<.+?| ) {
					$src2b = $res->content;
					$w2 = $1 + $2 + $3 + $4 + $5;
					$x2 = int( 0.5 + 10 * ( 5 * $1 + 4 * $2 + 3 * $3 + 2 * $4 + $5 ) / $w2 ) / 10;
					print "\n\tGoogle Books:\n\t\tRating:  $x2\n\t\tReviews: $w2\n";
				}
			}
			last if $w2 > 0;
			sleep( 5 );
		}
	}

	# Barbes & Noble
	my $url3 = "http://my.barnesandnoble.com/communityportal/ServiceRequest.aspx?uiAction=CustomerReviewsPageCallback&bnOutput=2&page=ReviewsCallback&ean=$isbn";
	my $x3 = 0;
	my $w3 = 0;
	my $src3 = 'No data';
	for( 1 .. $attempts ) {
		my $res = $ua->get( $url3 );
		if( $res->is_success and $res->content =~ m|customeravgrating="([0-9.]+)".+?customerratingcount="(\d+)"| ) {
			$src3 = $res->content;
			$x3 = $1;
			$w3 = $2;
			print "\n\tBarnes & Noble:\n\t\tRating:  $x3\n\t\tReviews: $w3\n";
		}
		last if $w3 > 0;
		sleep( 5 );
	}

	# LibraryThing
	my $url4 = "http://www.librarything.com/api/json/workinfo.js?ids=$isbn";
	my $x4 = 0;
	my $w4 = 0;
	my $src4 = 'No data';
	my $res = $ua->get( $url4 );
	$src4 = $res->content;
	if( $res->is_success and $res->content =~ m|,"reviews":"?([0-9]+)"?,"rating":"?([0-9.]+)"?,| ) {
		$w4 = $1;
		$x4 = $2 / 2;
		print "\n\tLibraryThing:\n\t\tRating:  $x4\n\t\tReviews: $w4\n";
	}

	# GoodReads
	my $url5 = "http://www.goodreads.com/search?q=$isbn";
	my $x5 = 0;
	my $w5 = 0;
	my $src5 = 'No data';
	for( 1 .. $attempts ) {
		my $res = $ua->get( $url5 );
		if( $res->is_success and $res->content =~ m|alt="([.0-9]+) of 5 stars"| ) {
			$src5 = $res->content;
			$x5 = $1;
			if( $res->content =~ m|>(\d+) ratings<| ) {
				$w5 = $1;
				print "\n\tGoodReads:\n\t\tRating:  $x5\n\t\tReviews: $w5\n";
			}
		}
		last if $w5 > 0;
		sleep( 5 );
	}

	# Validation
	$::valid = 1;
	print "\n\t\tValidating ISBN $isbn:\n";
	validate( 'Amazon', $isbn, $x1, $w1, $url1, $src1, $src1b );
	validate( 'GoogleBooks', $isbn, $x2, $w2, $url2, $src2, $src2b );
	validate( 'BarnesNoble', $isbn, $x3, $w3, $url3, $src3, '' );
	validate( 'LibraryThing', $isbn, $x4, $w4, $url4, $src4, '' );
	validate( 'GoodReads', $isbn, $x5, $w5, $url5, $src5, '' );

	if( $::valid ) {

		# Calculate weighted average
		$wa = int( 0.5 + 100 * ( $w1 * $x1 + $w2 * $x2 + $w3 * $x3 + $w4 * $x4 + $w5 * $x5 ) / ( $w1 + $w2 + $w3 + $w4 + $w5 ) ) / 100;
		$wt = $w1 + $w2 + $w3 + $w4 + $w5;
		print "\n\tWieghted average: $wa\n\tTotal reviews: $wt\n";

	} else { $wa = $wt = 0 }

	$::books++;
	$::valids++ if $::valid;
	$::invalids++ unless $::valid;
	$::cookies->clear;

	return( $wa, $wt );
}

# If any of the results are a problem, don't update the rating
sub validate {
	my $name = shift;
	my $isbn = shift;
	my $x1 = 0 + shift;
	my $w1 = 0 + shift;
	my $url = shift;
	my $src1 = shift;
	my $src2 = shift;
	print "\n\t\t\t$name:\n";

	# Set location of the data file and create if necessary
	my $dir = $::cache;
	mkdir $dir unless -e $dir;
	$dir .= "/$name";
	mkdir $dir unless -e $dir;
	my $file = "$dir/$isbn";

	# Load previous valid result if any
	$::x0 = 0;
	$::w0 = 0;
	if( -e $file ) {
		open FH, '<', $file;
		read FH, my $prev, -s $file;
		close FH;
		( $::x0, $::w0 ) = ( $1, $2 ) if $prev =~ /\s*(.+)\s*,\s*(.+)\s*/s;
		print "\t\t\tPrevious result found: ($::x0,$::w0)\n";
	}

	# If there's no current result, there's nothing we can do here, bail
	if( $::w0 == 0 and $w1 == 0 ) {
		print "\t\t\tNo previous or current results, nothing to do...\n";
		return;
	}

	# If no change, nothing to do
	if( $::w0 == $w1 and $::x0 == $x1 ) {
		print "\t\t\tNo change, nothing to do...\n";
		return;
	}

	# If the review count or rating is zero, scrape failed
	return sendError( "Could not retrieve data from page ($x1,$w1).", $name, $isbn, $url, $x1, $w1, $src1, $src2 ) if $w1 == 0 or $x1 == 0;

	# If there's a previous, then check that current is sane in comparison
	if( $::w0 > 0 ) {

		# Review count should never decrease
		return sendError( "Review count decreased from $::w0 to $w1.", $name, $isbn, $url, $x1, $w1, $src1, $src2 ) if $::w0 > $w1;

		# Review count should always be higher if the rating has changed
		return sendError( "Review count did not increase from $::w0, but the rating changed from $::x0 to $x1.", $name, $isbn, $url, $x1, $w1, $src1, $src2 ) if $::w0 == $w1 and $::x0 != $x1;

		# TODO: Increase in reviews determines maximum difference that the rating should be able to change by

	}

	# Save the current result
	print "\t\t\tSaving current result: ($x1,$w1)\n";
	open FH,'>', $file;
	print FH "$x1,$w1";
	close FH;
}
