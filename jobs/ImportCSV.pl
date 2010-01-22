#!/usr/bin/perl
#
# Subroutines for ImportCSV job called by wikid.pl (Organic Design wiki daemon)
#
# @author Aran Dunkley http://www.organicdesign.co.nz/nad
#

# Set the file pointer to start of the file (i.e. first line)
sub initImportCSV {
	$$::job{fptr} = 0;
	$$::job{rows} = 0;
	1;
}

# Import the current line from the input CSV file
sub mainImportCSV {
	my $wiki = $$::job{wiki};
	my $file = $$::job{file};
	my $fptr = $$::job{fptr};
	my $rows = $$::job{rows}++;
	my $tmpl = $$::job{template};
	my @data = ();

	# Read the CSV record from the indexed offset into an array
	if ( open INPUT, "<$file" ) {

		# Read a line accountung for multiline items in quotes
		seek INPUT, $fptr, 0;
		my $line = '';
		my $chr = '';
		my $i = 0;
		my $q = 0;
		do {
			$i = read INPUT, $chr, 1;
			$q++ if $chr eq '"';
			$line .= $chr;
		} while( $i && ( $q%2 || ( $chr ne "\r" && $chr ne "\n" ) ) );
		$$::job{fptr} = tell INPUT;
		close INPUT;
		workStopJob() if $i == 0;

		# Split and trim the line and remove quotes if any
		@data = split /\t/, $line;
		s/^\s*"?(.*?)"?\s*$/$1/s for @data;

	} else {
		workLogError( "Couldn't read input file \"$file\", job aborted!" );
		workStopJob();
	}

	# If this is the first row, define the columns and a reverse lookup
	if ( $fptr == 0 ) {
		$$::job{cols} = \@data;
		my %lut = ();
		$lut{lc $data[$_]} = $_ for 0 .. $#data;
		$$::job{lut} = \%lut;
	}

	# Otherwise construct record as wikitext and insert into wiki
	else {

		# Determine title for the record
		my $title = $$::job{title};
		if ( $title ) {
			$title =~ s/\$(\w+)/ jobImportCSVBuildTitle( $1, \@data ) /eg;
		} else { $title = wikiGuid() }

		# Construct the template syntax
		my @cols = @{ $$::job{cols} };
		my $text = "\{\{$tmpl\n";
		$text .= " | $cols[$_] = $data[$_]\n" for 0 .. $#cols;
		$text .= "\}\}";

		# Import into the wiki
		my $leaf = $1 if $file =~ /^.+\/(.+?)$/;
		my $comment = "New article created from \"$leaf\" import";
		my $minor = 1;
		my $cur = wikiRawPage( $wiki, $title );
		if ( $cur ) {
			$minor = 0;
			$comment = "Article content replaced from \"$leaf\" import";
		}
		$$::job{revisions}++ if wikiEdit( $wiki, $title, $text, $comment, $minor ) and $cur ne $text;
	}

	$$::job{status} = "Record $rows imported";
	1;
}

# Replace a token from the title format string with data
# - named indexes are case-insensitive
# - removes double spaces from result
sub jobImportCSVBuildTitle {
	my $i = shift;
	my $data = shift;
	my %lut = %{$$::job{lut}};
	my $title = $$data[ $i =~ /\D/ ? $lut{lc $i} : $i - 1 ];
	$title =~ s/ +/ /g;
	return $title;
}

sub stopImportCSV {
	1;
}

1;
