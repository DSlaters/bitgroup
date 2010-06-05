#!/usr/bin/perl
#
# Subroutines for "ModifyRecords" job called by wikid.pl (Organic Design wiki daemon)
#
# Copyright (C) 2009-2010 Aran Dunkley and others.
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

# Set the file pointer to start of the file (i.e. first line)
sub initModifyRecords {
	my @titles = wikiAllPages( $$::job{wiki} );
	$$::job{titles} = \@titles;
	$$::job{length} = $#titles;
	1;
}

# Import the current line from the input CSV file
sub mainModifyRecords {
	my $wiki    = $$::job{wiki};
	my $wptr    = $$::job{wptr};
	my $type    = $$::job{ChangeType};
	my $from    = $$::job{From};
	my $to      = $$::job{To};
	my $title   = $$::job{titles}[$$::job{wptr}];
	my $text    = wikiRawPage( $wiki, $title );
	my $last    = $text;
	my $comment = '';

	# Change all occurrences of a particular value to a different value
	# - accounts for lists <---------------------------------------------------------------------- ! ! !
	if ( $type eq 'value' ) {
		$text =~ s/^\s*\|\s*(\w+)\s*=\s*([^\|\}]*)/ " | $1 = " . jobModifyRecordsReplaceValue( $2, $from, $to ) /gem;
		$comment = "ModifyRecords: \"$from\" value changed to \"$to\"";
	}

	elsif ( $type eq 'field' ) {
	}

	elsif ( $type eq 'name' ) {
	}

	# Write back the article content if changed
	if ( $text ne $last ) {
		my $comment = 'Field values change';
		wikiEdit( $wiki, $title, $text, $comment, 1 );
		$$::job{revisions}++;
	}

	$$::job{status} = int( $$::job{revisions} ) . " items changed, processing \"$title\"";
	1;
}

# Replace a record value accounting for lists
sub jobModifyRecordsReplaceValue {
	my $value = shift;
	my $from  = shift;
	my $to    = shift;
	$value =~ s/^$from$/$to/m;
	return $value;
}

sub stopModifyRecords {
	1;
}

1;
