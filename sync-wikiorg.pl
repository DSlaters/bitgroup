#!/usr/bin/perl
#
# Synchronise the wiki-organisation content from one wiki to another
# - src and dst defined in wikid.conf by: $srcwiki, $srcuser, $srcpass, $dstwiki, $dstuser, $dstpass
# - if no src details are supplied, OD is used
#
#
# Copyright (C) 2010 Aran Dunkley and others.
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
require "wiki.pl";

$srcwiki = 'http://www.organicdesign.co.nz/wiki/index.php';
$srcuser = '';
$srcpass = '';

require "wikid.conf";

$srcdomain = $1 if $srcwiki =~ m|//(.+?)/|;
$comment = "Imported from $srcdomain by sync-wikiorg.pl";

wikiLogin( $srcwiki, $srcuser, $srcpass ) if $srcuser;
wikiLogin( $dstwiki, $dstuser, $dstpass ) if $dstuser;

# The DPL queries which select all the wiki organisation articles
# - does not select record instances
$query = "
	{{#dpl:namespace=Form}}
	{{#dpl:uses=Template:Portal}}
	{{#dpl:category=Records}}
	{{#dpl:category=RecordAdmin}}
	{{#dpl:category=Symbols}}
	{{#dpl:category=Formatting templates}}
	{{#dpl:category=Organisational templates}}
	{{#dpl:category=Common roles}}
	Organic Design
";

# Get the list of titles from the DPL queries
@titles = wikiParse( $srcwiki, $query, 1 );

# Ensure the list exhibits only unique titles
%tmp = ();
$tmp{$_} = 1 for @titles;
@titles = sort keys %tmp;

# Copy the titles from source wiki to destination wiki
for $title ( @titles ) {
	print "$title\n";
	$text = wikiRawPage( $srcwiki, $title );
	if ( $title =~ /^(Image|File):(.+)$/ ) {

		# Title is a file/image
		my $url = wikiGetFileUrl( $srcwiki, $2 );
		wikiUploadFile( $dstwiki, $url, '', $text );

	} else {

		# Title is a normal article
		wikiEdit( $dstwiki, $title, $text, $comment );

	}
}
