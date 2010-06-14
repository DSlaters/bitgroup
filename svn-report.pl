#!/usr/bin/perl
#
# svn-report.pl - Read meta data from an SVN repository into a file
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

$url = 'http://svn.wikimedia.org/viewvc/mediawiki';

# Todo: Make files name determined by url
$out = '/var/www/svn-report.txt';

# Set up a user agent
use HTTP::Request;
use LWP::UserAgent;
$client = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0',
	from       => 'svn-report.pl@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 20000
);

$found = true;

# Todo: Start at last processed revision in $out
$revision = 30000;

while ( $found ) {
	$revision++;
	$response = $client->get( "$url?view=rev&revision=$revision" );
	$content = $response->content;
	if ( $content =~ /<pre>404 Not Found<\/pre>/ ) {
		$found = false;
	} else {
		$core   = 0;
		$author = '';
		$date   = '';
		if ( $content =~ /<strong>Changed paths:<\/strong>.+phase3/s )   { $core = 1	} # Todo: Extract all path info
		if ( $content =~ /<th>Author:<\/th>\s*<td>(.*?)<\/td>/s )        { $author = $1 }
		if ( $content =~ /<th>Date:<\/th>\s*<td>(.+?)\s+UTC.*?<\/td>/s ) { $date = $1   }

		$line = "$revision,$date,$author,$core\n";
		print $line;
		open OUTH,'>>',$out or die "Can't open '$out' for writing!";
		print OUTH $line;
		close OUTH;
	}
}
