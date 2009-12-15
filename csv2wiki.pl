#!/usr/bin/perl
# - Licenced under LGPL (http://www.gnu.org/copyleft/lesser.html)
# - Authors: [http://www.organicdesign.co.nz/Nad Nad] and [http://www.organicdesign.co.nz/Sven Sven]
# - Source:  http://www.organicdesign.co.nz/csv2wiki.pl
# - Started: 2008-03-21
 
# Todo
# Make it so that if there is no title then it increments
# $hashref = { $wikitext =~ /\{{3}(.+?)(\|.*?)?\}{3}/g }
require( '/var/www/tools/wiki.pl' );

$csv2wiki_version = '2.0.1'; # 2009-12-15
 
# Job, log and error files
$ARGV[0] or die "No job file specified!";
$ARGV[0] =~ /^(.+?)(\..+?)?$/;

$log = "$1.log";
$err = "$1.err";
$sep = ",";
$multisep = "\n";
$title = 0;
$template = "Record";
$prefix = "";
$append = 0;
$titleformat = "";

# Parse the job file
if ( open JOB, '<', $ARGV[0] ) {
	for ( <JOB> ) {
		if ( /^\*?\s*\$?csv\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )          { $csv = $1 }
		if ( /^\*?\s*\$?wiki\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )         { $wiki = $1 }
		if ( /^\*?\s*\$?user\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )         { $user = $1 }
		if ( /^\*?\s*\$?pass\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )         { $pass = $1 }
		if ( /^\*?\s*\$?sep(arator)?\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i ) { $sep = $2 }
		if ( /^\*?\s*\$?multisep\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )     { $multisep = $1 }
		if ( /^\*?\s*\$?title\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )        { $titleformat = $1 }
		if ( /^\*?\s*\$?template\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )     { $template = $1 } 
		if ( /^\*?\s*\$?prefix\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )       { $prefix = $1 }
		if ( /^\*?\s*\$?append\s*[:=]\s*['"]?(.+?)['"]?;?\s*$/i )       { $append = $1 }
	}
	close JOB;
} else { die "Couldn't parse job file!" }
  
# Log in to the wiki and open input file
wikiLogin( $wiki, $user, $pass ) or die "Couldn't log $user in to $wiki";
open CSV, '<', $csv or die "Couldn't open input file '$csv'!";

# Process the records
my @fields = ();
my %lut = ();
my $wptr = 0;
while ( my $row = <CSV> ) {
	$row =~ s/^\s*['"]?(.+?)['"]?\s*$/$1/g;
	my @data = split /['"]?$sep['"]?/, $row;

	# If this is the first row, define the columns and a reverse lookup
	if ( $wptr == 0 ) {
		for ( @data ) {
			s/\W+/_/g;
			s/^_+//;
			s/_+$//;
			push @fields, $_;
		}
		$lut{lc $data[$_]} = $_ for 0 .. $#data;
	}

	# Build the record as wikitext template syntax
	else {
		my $tmpl = "{{$template";
		my $i = -1;
		for ( @data ) {
			s/^\s*(.+?)\s*$/$1/g;
			$tmpl .= $fields[++$i] ? "\n | $fields[$i] = $_" : ( $_ ? $multisep . $_ : '' );
		}
		$tmpl .= "\n}}";

		# Determine title for the record
		my $title = $titleformat;
		if ( $title ) {
			$title =~ s/\$(\w+)/ buildTitle( $1, \@data ) /eg;
		} else {
			$title = wikiGuid();
		}

		# Find the template in the wikitext if exists
		$text = wikiRawPage( $wiki, $title );
		for ( wikiExamineBraces( $text ) ) {
			( $pos, $len ) = ( $_->{OFFSET}, $_->{LENGTH} ) if $_->{NAME} eq $template;
		}

		# Replace, prepend or append the template into the current text 
		if ( defined $pos ) {
			substr $text, $pos, $len, $tmpl;
		} else {
			$text = $append ? "$text\n$tmpl" : "$tmpl\n$text";
		}

		# Update the article
		print "Processing row $wptr ($title)\n";
		my $comment = "[[Template:$::template|$::template]] replacement using csv2wiki.pl";
		wikiEdit( $wiki, $title, $text, $comment );
	}

	$wptr++;
}
 
close CSV;

# Replace a token from the title format string with data
# - named indexes are case-insensitive
# - removes double spaces from result
sub buildTitle {
	my $i = shift;
	my $data = shift;
	my $title = $$data[ $i =~ /\D/ ? $::lut{lc $i} : $i - 1 ];
	$title =~ s/ +/ /g;
	return $title;
}

