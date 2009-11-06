#!/usr/bin/perl
#
# Parse text of Bouvier's dictionary into a wiki
#
# A line containing just a single capital letter indicates the start of a new section whereby all words start with that letter.
# It's important to track this because some words don't start with their proper letter,
# for example, TO DISHONOR is listed under "D".
# Synonyms, e.g. AVOW or ADVOW
# Each description is a paragraph followed by zero or more numbered paragraphs starting at "2." 

$ver = '0.0.3'; # 2009-11-06

require('/var/www/tools/wiki.pl');

$wiki     = 'http://114.localhost/wiki/index.php';
$wikiuser = '****';
$wikipass = '****';
$file     = '/home/nad/Knowledge/Economy/Freemen Documents/Bouviers Law Dictionary/Bouvier.txt';

# Log into the target wiki
wikiLogin( $wiki, $wikiuser, $wikipass ) or die "Couldn't log into wiki!";

# Loop through the lines of the input file
$letter = 'A';
$write = 0;
open DICT, '<', $file or die "Could not open dictionary file '$file'!";
for ( <DICT> ) {

	# Start of a new term with synonym
	if ( /^([-A-Z ]+) or ([-A-Z ]+)[.,]/ ) { @titles = ( processTitle( $1 ), processTitle( $2 ) ) }

	# Start of a new term definition
	elsif ( /^([-A-Z ]+)[.,]/ ) { @titles = ( processTitle( $1 ) ) }

	# New letter of the alphabet starting
	elsif ( /^([A-Z])$/ ) { $letter = $1 }

	# Additional meaning of the current term
	elsif ( /^[0-9]+\.\s*(.+)$/ ) { $text .= "# $1\n" }

	# Create the articles, the first is the real content, subsequent ones are redirects
	if ( $write and $text ) {

		$text  = "{{Bouvier}}\n$text";
		$comment = "Term definition imported from Bouvier's dictionary";

		for ( @titles ) {
			print "$_\n";
			wikiEdit( $wiki, $_, $text, $comment );
			$text = "#REDIRECT [[$titles[0]]]\n" unless $comment;
			$comment = '';
		}

		$write = 0;
		$text = '';
	}

}


# Process a title string and return array of titles from the passed text
sub processTitle {
	$write = 1;
	my $title = shift;
	my @titles = ( $title, ucfirst lc $title );
	push @titles, $2 if $titles[0] =~ /^(.).* (.+)$/ and $1 ne $letter;
	push @titles, ucfirst lc $2 if $titles[0] =~ /^(.).* (.+)$/ and $1 ne $letter;
	return @titles;
}
