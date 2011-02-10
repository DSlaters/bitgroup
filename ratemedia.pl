#!/usr/bin/perl
#
# ratemedia.pl - Scan a directory of movie files and rename them to be preceded with their IMDB rating
#
# Copyright (C) 2011 Aran Dunkley
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
use LWP::UserAgent;

# Set up a global client for making HTTP requests as a browser
$ua = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'ratemedia@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 100000
);

#for( glob "*.??*" ) {
for( 'Fifty.Deadmen.Walking.avi' ) {
	$rating = rate( $_ );
}

sub rate {
	$name = shift;
	print "Looking up \"$name\":\n";
	$name =~ s/(720p|1080p|dvdrip|dvd)//gi;
	$name =~ s/\.\w+$//g;
	$name =~ s/[-_. ]+/+/g;
	$name =~ s/[+]$//;
	$name =~ s/[.~!()\[\]{}]+//g;
	( $title, $year ) = $name =~ m|(.+?)\+*(\d\d\d\d).+$| ? ( $1, $2 ) : ( $name, '' );
	$res = $ua->get( "http://www.imdb.com/find?s=all&q=$title" );
	if( $res->is_success ) {
		$link = undef;
		if( $year ) {
			$link = $1 if $res->content =~ m|<a href="(.+?)"[^>]+>(.+?)</a> \($year\)|i;
			print "\tTitle: $2 ($year)\n";
		} else {
			$link = $1 if $res->content =~ m|<a href="(.+?)"[^>]+>(.+?)</a> \((\d\d\d\d)\)|i;
			print "\tTitle:  $2 ($3)\n";
		}
		if( $link ) {
			$res = $ua->get( "http://www.imdb.com$link" );
			if( $res->is_success ) {
				( $votes, $rating ) = ( $1, $2 ) if $res->content =~ m|([0-9,]+) imdb users have given an average vote of ([0-9.]+)/10|i;
				print "\tRating: $rating (from $votes votes)\n" if $rating;
			}
		} else { print "\tnot found!\n" }
	}
	print "\n";
	return $rating;
}
