#!/usr/bin/perl
#
# Subroutines for ModifyRecords job called by wikid.pl (Organic Design wiki daemon)
#
# @author Aran Dunkley http://www.organicdesign.co.nz/nad
#

# Set the file pointer to start of the file (i.e. first line)
sub initModifyRecords {
	my @titles = wikiAllPages( $$::job{'wiki'} );
	$$::job{'titles'} = \@titles;
	$$::job{'length'} = $#titles;
	1;
}

# Import the current line from the input CSV file
sub mainModifyRecords {
	my $wiki    = $$::job{'wiki'};
	my $wptr    = $$::job{'wptr'};
	my $type    = $$::job{'ChangeType'};
	my $from    = $$::job{'From'};
	my $to      = $$::job{'To'};
	my $title   = $$::job{'titles'}[$$::job{'wptr'}];
	my $text    = wikiRawPage( $wiki, $title );
	my $last    = $text;
	my $comment = '';

	# Change all occurrences of a particular value to a different value
	# - accounts for lists <---------------------------------------------------------------------- ! ! !
	elsif ( $type eq 'value' ) {
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
		$$::job{'revisions'}++;
	}

	$$::job{'status'} = int( $$::job{'revisions'} ) . " items changed, processing \"$title\"";
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
