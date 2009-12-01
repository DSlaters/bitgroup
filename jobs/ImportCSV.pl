#!/usr/bin/perl
#
# Subroutines for ImportCSV job called by wikid.pl (Organic Design wiki daemon)
#
# @author Aran Dunkley http://www.organicdesign.co.nz/nad
#

sub initImportCSV {
	my $file = $$::job{'file'};
	my $errors = 0;

	# List the byte offsets of each line of the source file in an index file
	my $offset = 0;
	if ( open INPUT, "<$file" ) {
		if ( open INDEX, "+>$file.idx" ) {
			while ( <INPUT> ) {
				print INDEX pack 'N', $offset;
				$offset = tell INPUT;
				$$::job{'length'}++;
			}
			close INDEX;
		} else { $errors++ && workLogError( "Couldn't create and index file \"$file.idx\"" ) }
		close INPUT;
    } else { $errors++ && workLogError( "Couldn't open input file \"$file\"" ) }
    
	# Report errors and stop job if error count non zero
    if ( $errors > 0 ) {
		workLogError( "$errors errors were encountered, job aborted!" );
		workStopJob();
	}	

	1;
}

# Import the next line from the input CSV file
sub mainImportCSV {
	my $wiki = $$::job{'wiki'};
	my $file = $$::job{'file'};
	my $wptr = $$::job{'wptr'};
	my $tmpl = $$::job{'template'};

	# Find the offset to the current line from the index file
	open INDEX, "<$file.idx";
	my $size = length pack 'N', 0;
	seek INDEX, $size * $wptr, 0;
	read INDEX, my $offset, $size;
	$offset = unpack( 'N', $offset );
	close INDEX;

	# Read the CSV record from the indexed offset into an array
	open INPUT, "<$file";
	seek INPUT, $offset, 0;
	my @data = split /\t/, <INPUT>;
	s/^\s*(.*?)\s*$/$1/s for @data;
	close INPUT;

	# If this is the first row, define the columns and a reverse lookup
	if ( $wptr == 0 ) {
		$$::job{'cols'} = \@data;
		my %lut = ();
		$lut{lc $data[$_]} = $_ for 0 .. $#data;
		$$::job{'lut'} = \%lut;
	}

	# Otherwise construct record as wikitext and insert into wiki
	else {

		# Determine title for the record
		my $title = $$::job{'title'};
		if ( $title ) {
			$title =~ s/\$(\w+)/ jobImportCSVBuildTitle( $1, \@data ) /eg;
		} else { $title = wikiGuid() }

		# Construct the template syntax
		my @cols = @{ $$::job{'cols'} };
		my $text = "\{\{$tmpl\n";
		$text .= " | $cols[$_] = $data[$_]\n" for 0 .. $#cols;
		$text .= "\}\}";

		# Import into the wiki
		my $cur = wikiRawPage( $wiki, $title );
		$$::job{'revisions'}++ if wikiEdit( $wiki, $title, $text, "Content imported from \"$file\"" ) and $cur ne $text;
	}

	$$::job{'status'} = "Record $ptr imported";
	1;
}

# Replace a token from the title format string with data
# - named indexes are case-insensitive
# - removes double spaces from result
sub jobImportCSVBuildTitle {
	my $i = shift;
	my $data = shift;
	my %lut = %{$$::job{'lut'}};
	my $title = $$data[ $i =~ /\D/ ? $lut{lc $i} : $i - 1 ];
	$title =~ s/ +/ /g;
	return $title;
}

# Remove the index file when the job is finished or stopped
sub stopImportCSV {
	my $file = $$::job{'file'};
	unlink "$file.idx";
	1;
}

1;
