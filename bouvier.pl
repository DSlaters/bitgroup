#!/usr/bin/perl
#
# Parse text of Bouvier's dictionary into a wiki
#
# A line containing just a single capital letter indicates the start of a new section whereby all words start with that letter.
# It's important to track this because some words don't start with their proper letter,
# for example, TO DISHONOR is listed under "D".
# Synonyms, e.g. AVOW or ADVOW
# Each description is a paragraph followed by zero or more numbered paragraphs starting at "2." 
# Some words such as ABANDONMENT have many entries, so each should be added as a separate paragraph

$ver = '1.0.0'; # 2009-11-07

require( '/var/www/tools/wiki.pl' );

$wiki     = 'http://114.localhost/wiki/index.php';
$wikiuser = 'Nad';
$wikipass = 'yN$ger0';
$file     = '/home/nad/Knowledge/Economy/Freemen Documents/Bouviers Law Dictionary/Bouvier.txt';

# Log into the target wiki
wikiLogin( $wiki, $wikiuser, $wikipass ) or die "Couldn't log into wiki!";

# First pass - loop through the lines of the input file creating the entries in %dict
%dict = ();
$letter = 'A';
open DICT, '<', $file or die "Could not open dictionary file '$file'!";
for ( <DICT> ) {

	@last = ();

	# Start of a new term with synonym
	if ( /^([-A-Z ]+) or ([-A-Z ]+)[.,]/ ) {
		$next = $_;
		@last = @titles;
		@titles = ( processTitle( $1 ), processTitle( $2 ) );
	}

	# Start of a new term definition
	elsif ( /^([-A-Z ]+)[.,]/ ) {
		$next = $_;
		@last = @titles;
		@titles = ( processTitle( $1 ) );
	}

	# New letter of the alphabet starting
	elsif ( /^([A-Z])$/ ) {
		@last = @titles;
		$letter = $1;
	}

	# Additional meaning of the current term
	elsif ( /^([0-9]+\.)\s*(.+)$/ ) {
		$text .= "'''$1''' $2\n\n";
	}
	
	else {
		$text .= " $_";
	}

	# Create the articles, the first is the real content, subsequent ones are redirects
	if ( $text and $#last >= 0 ) {

		$key = shift @last;

		# If title already exists append current definition
		if ( -e $dict{$key} ) {
			@entry = @{ $dict{$key} };
			$text = $entry[0] . "\n\n$text";
		}

		$dict{$key} = [ $text, [ @last ] ];
		$text = "$next\n";
		$text =~ s/^([-A-Z ]{3,})(?=[.,])/'''$1'''/mg;
	}
}


# Second pass - run through the hash keys creating articles
for $key ( keys %dict ) {
	@entry = @{ $dict{$key} };
	@titles = ( $key, @{ $entry[1] } );
	$text  = "{{Bouvier}}\n$entry[0]";
	$comment = "Term definition imported from Bouvier's dictionary";
	for ( @titles ) {
		wikiEdit( $wiki, $_, $text, $comment );
		$text = "#REDIRECT [[$key]]\n" if $comment;
		$comment = '';
	}
	exit if $x++ > 20;
}


# Process a title string and return array of titles from the passed text
sub processTitle {
	my $title = shift;
	my @titles = ( $title, ucfirst lc $title );
	push @titles, $2 if $titles[0] =~ /^(.).* (.+)$/ and $1 ne $letter;
	push @titles, ucfirst lc $2 if $titles[0] =~ /^(.).* (.+)$/ and $1 ne $letter;
	return @titles;
}
