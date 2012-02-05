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
use LWP::UserAgent;
use URI::Escape;
$wiki = 'http://whatleadership.organicdesign.co.nz/wiki/index.php';
$isbn = $ARGV[0];
$ua = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'crowdrating@organicdesign.co.nz',
	timeout    => 10,
);

# Get the current top-ten leadership books from inc.com
$res = $ua->get( "http://www.inc.com/ss/best-leadership-books-of-all-time" );
if( $res->is_success ) {
	@matches = $res->content =~ m|class='slide slide-[1-9]\d* slide-player'.+?<img.+?title="(&lt;em&gt;)?([^"]+?)(&lt;/em&gt;)? by (.+?) \(.+?\)"|sg;
	for( $i = 0; $i < $#matches; $i += 4 ) {
		$title = uri_escape( $matches[$i+1] );
		$author = uri_escape( $matches[$i+3] );
		$res = $ua->get( "$wiki?action=createbook&booktitle=$title&author=$author" );
		print "\n\t" . $res->content . "\n" if $res->is_success;
exit;
	}
}

