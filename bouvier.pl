#!/usr/bin/perl

# A line containing just a single capital letter indicates the start of a new section whereby all words start with that letter.
# It's important to track this because some words don't start with their proper letter,
# for example, TO DISHONOR is listed under "D".
# Synonyms, e.g. AVOW or ADVOW
# Each description is a paragraph followed by zero or more numbered paragraphs starting at "2." 
    
require('/var/www/tools/wiki.pl');

$wiki     = 'http://wiki.translatum.gr/w/index.php';
$wikiuser = '****';
$wikipass = '****';
$file     = '/home/nad/Knowledge/Economy/Freemen Documents/Bouviers Law Dictionary/Bouvier.txt';

# Log into the target wiki
wikiLogin( $wiki, $wikiuser, $wikipass ) or die "Couldn't log into wiki!";

# Loop through the lines of the input file
$file   = $ARGV[0];
$letter = 'A';
open DICT, '<', $file or die "Could not open dictionary file '$file'!";
for ( <DICT> ) {

	# New letter of the alphabet starting
	if ( /^([A-Z])$/ ) { $letter = $1 }

	# Additional meaning of the current term
	elsif ( /^[0-9]+\.\s*(.+)$/ ) { $text .= "# $1\n" }

	# Create/overwrite the primary definition article
	$text  = "{{Bouvier}}\n\n";
	$comment = "Term definition imported from Bouvier's dictionary";

	# Create the articles, the first is the real content, subsequent ones are redirects
	for ( @titles ) {
		print lc $_ . "\n";
		wikiEdit( $wiki, $_, $text, $comment );
		$text = "#REDIRECT [[$title]]" if $comment;
		$comment = '';
	}

}
