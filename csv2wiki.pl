#!/usr/bin/perl
# - Licenced under LGPL (http://www.gnu.org/copyleft/lesser.html)
# - Authors: [http://www.organicdesign.co.nz/Nad Nad] and [http://www.organicdesign.co.nz/Sven Sven]
# - Source:  http://www.organicdesign.co.nz/csv2wiki.pl
# - Started: 2008-03-21
 
# Todo
# Make it so that if there is no title then it increments
# $hashref = { $wikitext =~ /\{{3}(.+?)(\|.*?)?\}{3}/g }
require( 'wiki.pl' );

$::csv2wiki_version = '2.0.1'; # 2009-12-15
 
# Job, log and error files
$ARGV[0] or die "No job file specified!";
$ARGV[0] =~ /^(.+?)(\..+?)?$/;

# Set a debug conditional
$::debug = 0;

$::log = "$1.log";
$::err = "$1.err";
$::sep = ",";
$::multisep = "\n";
$::title = 0;
$::template = "Record";
$::prefix = "";
$::append = 0;
 
# Parse the job file
if ( open JOB,'<',$ARGV[0] ) {
	for ( <JOB> ) {
		if ( /^\*?\s*\$?csv\s*[:=]\s*(.+?)\s*$/i )         { $::csv = $1 }
		if ( /^\*?\s*\$?wiki\s*[:=]\s*(.+?)\s*$/i )        { $::wiki = $1 }
		if ( /^\*?\s*\$?user\s*[:=]\s*(.+?)\s*$/i )        { $::user = $1 }
		if ( /^\*?\s*\$?pass\s*[:=]\s*(.+?)\s*$/i )        { $::pass = $1 }
		if ( /^\*?\s*\$?separator\s*[:=]\s*"(.+?)"\s*$/i ) { $::sep = $1 }
		if ( /^\*?\s*\$?multisep\s*[:=]\s*"(.+?)"\s*$/i )  { $::multisep = $1 }
		if ( /^\*?\s*\$?title\s*[:=]\s*(.+?)\s*$/i )       { $::title = $1 }
		if ( /^\*?\s*\$?template\s*[:=]\s*(.+?)\s*$/i )    { $::template = $1 } 
		if ( /^\*?\s*\$?prefix\s*[:=]\s*(.+?)\s*$/i )      { $::prefix = $1 }
		if ( /^\*?\s*\$?append\s*[:=]\s*(.+?)\s*$/i )      { $::append = $1 }
	}
	close JOB;
} else { die "Couldn't parse job file!" }
 

# Open CSV file and read in headings line
if ( open CSV, '<', $::csv ) {
	$_ = <CSV>;
	/^\s*(.+?)\s*$/;
	@headings = split /$::sep/i, $1;
} else { die "Could not open CSV file!" }
 
# Log in to the wiki
wikiLogin( $::wiki, $::user, $::pass ) or exit;


# Get the parameters from the first row of the input file
my $head = <CSV>;
$head =~ s/^\s*(.+?)\s*$/$1/g;
@fields = split /$::sep/, $head;

# Process the records
while my $row ( <CSV> ) {

	# Build the record as wikitext template syntax
	my $tmpl = "{{$template";
	my $i    = 0;
	my $last = '';
	for my $value ( split /$::sep/, $row ) {
		$value =~ s/^\s*(.+?)\s*$/$1/g;
		if ( $field = $fields[$i] ) {
			$tmpl .= "\n | $field = $value";
			$last = $field;
		} else {
			$tmpl .= $::multisep . $value;
			$field = $last;
		}
		$i++;
	}
	$tmpl .= "\n}}";

	print "Processing record ".$n++."\n";
	if ( $::debug ) {
	    print "\$tmpl = $tmpl\n";
	    die   "[\$::debug set exiting]\n" ;
	}

	# Get the current text of the wiki article to be created/updated
	$text = wikiRawPage( $::wiki,$record[$::title], 0 );

	# Find the template in the wikitext if exists
	for ( examineBraces( $text ) ) {
		( $pos, $len ) = ( $_->{OFFSET}, $_->{LENGTH} ) if $_->{NAME} eq $template;
	}

	# Replace, prepend or append the template into the current text 
	if ( defined $pos ) {
		$text = substr $text, $pos, $len, $tmpl;
	} else {
		$text = $append ? "$text\n$tmpl" : "$tmpl\n$text";
	}

	# Update the article
	$done = wikiEdit(
		$::wiki,
		$::prefix . $record[$::title],
		$text,
		"[[Template:$::template|$::template]] replacement using csv2wiki.pl"
	);

}
 
close CSV;


# Returns a hash of brace structures
# - see http://www.organicdesign.co.nz/MediaWiki_code_snippets
sub examineBraces {
	my $content = shift;
	my @braces  = ();
	my @depths  = ();
	my $depth   = 0;
	while ( $content =~ m/\G.*?(\{\{\s*([#a-z0-9_]*:?)|\}\})/sig ) {
		my $offset = pos( $content ) - length( $2 ) - 2;
		if ( $1 eq '}}' ) {
			$brace = $braces[$depths[$depth - 1]];
			$$brace{LENGTH} = $offset - $$brace{OFFSET} + 2;
			$$brace{DEPTH}  = $depth--;
		} else {
			push @braces, { NAME => $2, OFFSET => $offset };
			$depths[$depth++] = $#braces;
		}
	}
	return @braces;
}
