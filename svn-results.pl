#!/usr/bin/perl
#
# svn-results.pl - Generate report of number of SVN committers by month
#
# Copyright (C) 2008-2010 Aran Dunkley
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

use Date::Format;
use Date::Parse;

$csv = '/var/www/svn-report.txt';
%data = ();

open CSV,'<',$csv;
while ( <CSV> ) {
	( $revision,$date,$user,$core ) = split ',';
	if ( $date =~ /... (...) .. ..:..:.. (....)/ && $user ) {
		$data{time2str( '%Y/%m', str2time( "1 $1 $2" ) )}{$user}{0+$core}++;
		$data{time2str( '%Y', str2time( "1 $1 $2" ) )}{$user}{0+$core}++;
	}
}
close CSV;

print "$revision revisions read into hash\n";

for $date ( sort { $a cmp $b } keys %data ) {

	@users = keys %{ $data{$date} };
	$n = 1+$#users;
	$ncore = 0;
	$t = 0;
	$tcore = 0;
	for ( @users ) {
		if ( $c = $data{$date}{$_}{1} ) {
			$ncore++;
			$tcore += $c;
		}
		$t += $c + $data{$date}{$_}{0};
	}
	if ( $date =~ /^....$/ ) {
		print "\n|-\n|'''$date'''||'''$n'''||'''$ncore'''||'''$t'''||'''$tcore'''\n";
	}
	else {
		$date = time2str( '%B', str2time( "$date/01" ) );
		print "|-\n|$date||$n||$ncore||$t||$tcore\n";
	}
}
