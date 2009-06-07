#!/usr/bin/perl
# Imports rows from an OpenOffice spreadsheet file (*.ods) into wiki record articles{{perl}}
# - processes only the first sheet
# - ignores empty rows
use strict;
require('xml.pl');
require('wiki.pl');



# The details of the wiki to add the records to
my $wiki = 'http://svn.localhost/wiki/index.php';
my $user = 'foo';
my $pass = 'bar';

# The name of the record template
my $tmpl = 'Activity';

# Whether to append or prepend new records to existing articles
my $append = 0;

# Column names and regex to determine rows to extract (case insensitive)
my %filter = (
	'type' => 'hours'
);

# Specify the column headers or leave empty to use data from first row
my @columns = ('Day', 'Month', 'Year', 'From', 'To', 'Reference', 'Description', 'Type', 'Amount', 'Balance');



# Log in to the wiki
wikiLogin($wiki, $user, $pass) or exit;

# Extract the content.xml file from the .ods archive
my $xml = $ARGV[0] or die "Please specify a .ods file to import rows from";

# Convert the XML to a hash tree (see http://www.organicdesign.co.nz/xml.pl)
$xml = xmlParse(join('', qx( unzip -p $xml content.xml )));

# Sort out column names and order
my %cols = ();
$cols{lc $columns[$_]} = $_ for 0..$#columns;
if ($#columns < 0) {
	@columns = keys %cols;
	while (my($k, $v) = each(%cols)) { $columns[$v] = $k }
}

# Extract the data from the hash tree and add to the wiki
for (@{$$xml{-content}}) {
	for (@{$$_{-content}}) {
		if ($$_{-name} eq 'office:body') {
			for (@{$$_{-content}}) {
				my $done = 0;
				for (@{$$_{-content}}) {
					
					# Only process rows for the first sheet
					if ($$_{-name} eq 'table:table' && $done == 0) {
						$done++;
						
						# Loop through the rows of this sheet
						for (@{$$_{-content}}) {
							my @row = ();
							for (@{$$_{-content}}) {
								
								# Add this cell's content to the row
								my $cell = '';
								$cell = $$_{-content}[0] for @{$$_{-content}};
								push @row, $cell;
								
								# Handle the table:number-columns-repeated attribute
								if (defined $$_{'table:number-columns-repeated'} && $$_{'table:number-columns-repeated'} < 100) {
									push @row, $cell while --$$_{'table:number-columns-repeated'};
								}
							}
							
							# Process this row (unless empty)
							if (join('', @row)) {
								
								# Process this data row (or define cols if first row)
								my @kc = keys %cols;
								if ($#kc < 0) {
									for (0..$#row) {
										$cols{lc $row[$_]} = $_ if $row[$_];
									}
								} else {
									
									# Check if it passes through the filter
									my $fail = 0;
									while (my($col, $pat) = each(%filter)) {
										$fail = 1 unless $row[$cols{lc $col}] =~ /$pat/i;
									}
									
									# Process this row if it passed
									unless ($fail) {

										# Create record article title
										my $title = wikiGuid();

										# Get the current text of the article to be created/updated if any
										my $text = wikiRawPage($wiki, $title, 0);
										my $action = $text ? 'updated' : 'created';

										# Build the record as wikitext template syntax
										my $record  = "{{$tmpl\n";
										$record .= "|$_ = ".$row[$cols{lc $_}]."\n" for @columns;
										$record .= "}}";

										# Replace, prepend or append the template into the current text
										my ($pos, $len) = (0, 0);
										for (wikiExamineBraces($text)) {
											($pos, $len) = ($_->{OFFSET}, $_->{LENGTH}) if $_->{NAME} eq $tmpl;
										}
										if ($pos) { $text = substr $text, $pos, $len, $record }
										else { $text = $append ? "$text\n$record" : "$record\n$text" }

										# Update the article
										$done = wikiEdit(
											$wiki,
											$title,
											$record,
											"[[Template:$tmpl|$tmpl]] record $action by [[OD:Ods2wiki.pl|ods2wiki.pl]]"
										);
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
