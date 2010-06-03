#!/usr/bin/perl
#
# guidify.pl - converts a Wiki Organisation to all-GUID record names
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
require( '/var/www/tools/wiki.pl' );
require( '/var/www/tools/wikid.conf' );

# Login to the wiki
wikiLogin( $wiki, $wikiuser, $wikipass );


# Get record types (Category:Records)

# Read all instances into a hash by title

# Loop through the instances
while ( ( $title, $record ) = each %records ) {
	
	# Check if the type is GUID
	if ( $title =~ /^\d{8}-\W{5}$/ ) {

		# Create a GUID with date part matching the creation date of the record
		my @first = wikiFirstEdit( $wiki, $title );
		my $guid = wikiGuid( $first[0] );
		$$record{guid} = $guid;
		
		# Scan all instances for references to the old title and update their content
		while ( ( $t2, $r2 ) = each %records ) {
			my $tmp = $$r2{content};
			$$r2{content} =~ s/$title/$guid/g;
			$$r2{changed} = 1 if $$r2{content} ne $tmp;
		}
		
	}
	
}

# Loop through all instances again and write changes to the wiki
while ( ( $title, $record ) = each %records ) {
	
	# If the record has a new GUID, rename it, add a name parameter and free the old title
	if ( $$record{guid} ) {

		# Move the instance to a GUID name (& its talk)
		
		# Add a name parameter set to the old title
		
		# Delete the redirect (and talk redirect)
	}
	
	# If it's not a new GUID, but does have changes, update it
	elsif ( $$record{changed} ) {
		wikiEdit( $wiki, $title, $$record{content}, "References changed to GUIDs by [[guidify.pl]]" );
	}

}


# Log out
wikiLogout( $wiki );
