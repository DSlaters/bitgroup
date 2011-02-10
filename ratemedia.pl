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

$ua = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'ratemedia@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 100000
);

for( grep !/^IMDB/, glob "*" ) {
	print "\nChecking file \"$_\"\n";
	$file = $_;
	$ext = $1 if s/(\.\w+)$//g;
	s/(720p|1080p|x264|dvdrip|dvd|xvid|bluray).+//gi;
	s/[-_. \$]+/+/g;
	s/[+]$//;
	s/^[+]//;
	s/[.~!()\[\]{}]+//g;
	( $title, $year ) = m|(.+?)\+*(\d\d\d\d).*$| ? ( lc $1, $2 ) : ( lc $_, '\\d\\d\\d\\d' );
	print "\tQuery:  $title\n";
	$res = $ua->get( "http://www.imdb.com/find?s=all&q=$title" );
	if( $res->is_success ) {
		$res->content =~ m|<a href="(/title/[^"]+)"[^>]+>([^<]+)</a> \(($year)\)|i
			? $res = $ua->get( "http://www.imdb.com$1" )
			: $res->content =~ m|<title(>)(.+?) \(($year)\)|i;
		$title = "$2 ($3)";
		$title =~ s/&#x([0-9a-f]+);/chr(hex($1))/ige;
		print "\tTitle:  $title\n";
		if( $res->is_success and $res->content =~ m|([0-9,]+) imdb users have given an average vote of ([0-9.]+)/10|i ) {
			print "\tRating: $2 (from $1 votes)\n";
			print "\tRename: IMDB $2 - $title$ext\n";
		} else { print "\tERROR: Rating not found.\n" }
	} else { print "\tERROR: Movie not found!\n" }
}

