#!/usr/bin/perl
#
# Subroutines for ModifyRecords job called by wikid.pl (Organic Design wiki daemon)
#
# @author Aran Dunkley http://www.organicdesign.co.nz/nad
#

# Set the file pointer to start of the file (i.e. first line)
sub initModifyRecords {
	1;
}

# Import the current line from the input CSV file
sub mainModifyRecords {
	my $wiki = $$::job{'wiki'};
	my $wptr = $$::job{'wptr'};

	1;
}

sub stopModifyRecords {
	1;
}

1;
