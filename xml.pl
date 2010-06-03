#!/usr/bin/perl
#
# Copyright (C) 2007-2010 Aran Dunkley and others.
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
#
# A snipit for reading/writing nodal XML files
# - It can handle:		Attributes, Mixed content
# - It cannot handle:	Badly formed XML, CDATA sections
#
use strict;

# The XML is parse into a tree
# - each node in the tree is a hash of attributes plus -name and -content keys
# - each -content value is a ref to a list of ordered nodes/texts
# - only one root is allowed
sub xmlParse {
	
	# First convert XML into a list split at every tag, ie. <tag> </tag> or <tag/>
	# - Each tag is five list items (first /, name, atts, second /, text between this and next)
	@_ = shift =~ /<\s*(\/?)([-a-z0-9_:]+)\s*(.*?)\s*(\/)?>\s*(.*?)\s*(?=<|$)/gi;
	
	# Loop through all the tags and compile them into a tree
	my $ptr = my $root = {};
	my @path = ();
	while ( $#_ >= 0 ) {
		my ( $close, $name, $atts, $leaf, $text ) = ( shift, shift, shift, shift, shift );
		# Create a new node in the current content and update ptr if <tag/> or <tag>
		# - Includes hash of atts: /PATTERN/g returns a key,val list which can be treated as a hash
		unless ($close) {
			my $node = { -name => $name, $atts =~ /([-a-z0-9_:]+)\s*=\s*"(.*?)"/gi };
			push @{$$ptr{-content}}, $node;       # Push the node onto the current content list
			push @path, $ptr;                       # Move current focus into the new node
			$ptr = $node;
		}
		$ptr = pop @path if $close or $leaf;        # Move ptr up one level is </tag> or <tag/>
		push @{$$ptr{-content}}, $text if $text;  # Add the after-node-content part to the current level
	}
	return $root;
}


# Construct XML text from passed hash tree
sub xmlBuild {
	my ($level, $ptr) = @_;
	my $indent;
	$indent .= '   ' for 1..$level;
	my $xml = '';
	my $name = $$ptr{-name};
	$xml .= "$indent$name" if $name;
	for ( @{$$ptr{-content}} ) { $xml .= ref eq 'HASH' ? "\n".xmlBuild( $level+1, $_ ) : " => $_\n" }
	return $xml;
}

return 1;
