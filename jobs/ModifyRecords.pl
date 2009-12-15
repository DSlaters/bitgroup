#!/usr/bin/perl
#
# Subroutines for ModifyRecords job called by wikid.pl (Organic Design wiki daemon)
#
# @author Aran Dunkley http://www.organicdesign.co.nz/nad
#

# Set the file pointer to start of the file (i.e. first line)
sub initModifyRecords {
	my $wiki = $$::job{'wiki'};
	my @titles = wikiAllPages( $wiki );
	$$::job{'titles'}    = \@titles;
	$$::job{'length'}    = $#titles;
	$$::job{'wptr'}      = 0;
	$$::job{'revisions'} = 0;
	1;
}

# Import the current line from the input CSV file
sub mainModifyRecords {
	my $wiki  = $$::job{'wiki'};
	my $wptr  = $$::job{'wptr'};
	my $type  = $$::job{'ChangeType'};
	my $from  = $$::job{'From'};
	my $to    = $$::job{'To'};
	my $title = $$::job{'titles'}[$$::job{'wptr'}];
	my $text  = wikiRawPage( $wiki, $title );
	my $last  = $text;

	# Change all occurrences of a particular value to a different value
	# - accounts for lists
	elsif ( $type eq 'value' ) {
		
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

sub stopModifyRecords {
	1;
}

1;
