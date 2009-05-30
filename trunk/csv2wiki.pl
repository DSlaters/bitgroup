#!/usr/bin/perl
# {{perl}}{{Category:Robots}}{{lowercase}}
# - Licenced under LGPL (http://www.gnu.org/copyleft/lesser.html)
# - Authors:  [http://www.organicdesign.co.nz/Nad Nad] [http://www.organicdesign.co.nz/Sven Sven]
# - Source:  http://www.organicdesign.co.nz/csv2wiki.pl
# - Started: 2008-03-21
# - API:     http://en.wikipedia.org/w/api.php
 
# Todo
# Make it so that if there is no title then it increments
# $hashref = { $wikitext =~ /\{{3}(.+?)(\|.*?)?\}{3}/g }
require('wiki.pl');
 
# Job, log and error files
$ARGV[0] or die "No job file specified!";
$ARGV[0] =~ /^(.+?)(\..+?)?$/;

# Set a debug conditional
$::debug = 0;

$::log = "$1.log";
$::err = "$1.err";
$::sep = ',';
$::title = 0;
$::template = 'Record';
$::prefix = "";
$::append = 0;
 
# Parse the job file
if (open JOB,'<',$ARGV[0]) {
	for (<JOB>) {
		if (/^\*?\s*csv\s*:\s*(.+?)\s*$/i)         { $::csv = $1 }
		if (/^\*?\s*wiki\s*:\s*(.+?)\s*$/i)        { $::wiki = $1 }
		if (/^\*?\s*user\s*:\s*(.+?)\s*$/i)        { $::user = $1 }
		if (/^\*?\s*pass\s*:\s*(.+?)\s*$/i)        { $::pass = $1 }
		if (/^\*?\s*separator\s*:\s*"(.+?)"\s*$/i) { $::sep = $1 }
		if (/^\*?\s*title\s*:\s*(.+?)\s*$/i)       { $::title = $1 }
		if (/^\*?\s*template\s*:\s*(.+?)\s*$/i)    { $::template = $1 } 
		if (/^\*?\s*prefix\s*:\s*(.+?)\s*$/i)      { $::prefix = $1 }
		if (/^\*?\s*append\s*:\s*(.+?)\s*$/i)      { $::append = $1 }
	}
	close JOB;
} else { die "Couldn't parse job file!" }
 

# Open CSV file and read in headings line
if (open CSV, '<', $::csv) {
	$_ = <CSV>;
	/^\s*(.+?)\s*$/;
	@headings = split /$::sep/i, $1;
} else { die "Could not open CSV file!" }
 
# Log in to the wiki
wikiLogin($::wiki,$::user,$::pass) or exit;
 
# fetch the template if it exists
$response = $client->get("$wiki?title=Template:$template&action=raw");
if ($response->is_success) {
	$wikitext = $response->content;

	# Remove noinclude areas
	$wikitext =~ s/<noinclude>.+?<\/noinclude>//gs;

	# Find all unique {{{parameters}}}
	# http://en.wikipedia.org/wiki/Help:Templates#Parameters

	$params{$1} = undef while $wikitext =~ /\{{3}(.+?)(\|.*?)?\}{3}/g;

	# Create %{param=index} hash
	foreach ($i = 0; $i <= $#headings; $i++) {
		$params{$headings[$i]} = $i if exists $params{$headings[$i]};
	}

	if ($::debug) {
		print "\@headings: @headings\n";
		print "%params: @{[%params]}\n";
	}
}
  
# Get batch size and current number (also later account for n-bots)

# todo: log batch start
 
# Process the records
$n = 1;
while (<CSV>) {

	# Extract next record from input file
	/^\s*(.+?)\s*$/;
	@record = split /$::sep/, $1;

	# Build the record as wikitext template syntax
	$tmpl  = "{{$template\n";
	$tmpl .= "|$_ = $record[$params{$_}]\n" foreach keys %params;
	$tmpl .= "}}";

	print "Processing record ".$n++."\n";
	if ($::debug) {
	    print "\$tmpl = $tmpl\n";
	    die   "[\$::debug set exiting]\n" ;
	}

	# Get the current text of the wiki article to be created/updated
	$text = wikiRawPage($::wiki,$record[$::title],0);

	# Replace, prepend or append the template into the current text 
	for (examineBraces($text)) { ($pos, $len) = ($_->{OFFSET}, $_->{LENGTH}) if $_->{NAME} eq $template }
	if (defined $pos) { $text = substr $text, $pos, $len, $tmpl }
	else { $text = $append ? "$text\n$tmpl" : "$tmpl\n$text" }

	# Update the article
	$done = wikiEdit(
		$::wiki,
		$::prefix . $record[$::title],
		$text,
		"[[Template:$::template|$::template]] replacement using csv2wiki.pl"
	);

	# log a row error if any
}
 
close CSV;


# See http://www.organicdesign.co.nz/MediaWiki_code_snippets
sub examineBraces {
        my $content = shift;
        my @braces  = ();
        my @depths  = ();
        my $depth   = 0;
        while ($content =~ m/\G.*?(\{\{\s*([#a-z0-9_]*:?)|\}\})/sig) {
                my $offset = pos($content)-length($2)-2;
                if ($1 eq '}}') {
                        $brace = $braces[$depths[$depth-1]];
                        $$brace{LENGTH} = $offset-$$brace{OFFSET}+2;
                        $$brace{DEPTH}  = $depth--;
                } else {
                        push @braces, { NAME => $2, OFFSET => $offset };
                        $depths[$depth++] = $#braces;
                }
        }
        return @braces;
}
