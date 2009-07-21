#!/usr/bin/perl
# {{perl}}
use DBI;
require "wiki.pl";
require "wikid.conf";

# DB settings
$dbname = 'od';
$dbpfix = '';
$dbuser = wikiGetConfig( 'wgDBuser' );
$dbpass = wikiGetConfig( 'wgDBpass' );

# Login to wiki
wikiLogin( $wiki, $name, $wikipass );
my %ns = wikiGetNamespaces( $wiki );

# Connect to DB
my $dbh = DBI->connect( 'DBI:mysql:'.$dbname, lc $dbuser, $dbpass ) or die DBI->errstr;

# get a list of all titles in a category
my @list = ();
my $sth = $dbh->prepare( 'SELECT cl_from FROM categorylinks WHERE cl_to = "PERL"' );
$sth->execute();
push @list, @row[0] while @row = $sth->fetchrow_array;
$sth->finish;

# Uncomment this to loop through all articles in the wiki
#my $sth = $dbh->prepare( 'SELECT page_id FROM '.$::dbpfix.'page WHERE page_title = "Zhconversiontable"' );
#$sth->execute();
#my @row = $sth->fetchrow_array;
#$sth->finish;
#my $first = $row[0]+1;
#my $sth = $dbh->prepare( 'SELECT page_id FROM '.$::dbpfix.'page ORDER BY page_id DESC' );
#$sth->execute();
#@row = $sth->fetchrow_array;
#$sth->finish;
#my $last = $row[0];
#@list = ( $first .. $last );

# Loop through all articles one per second
my $sthid = $dbh->prepare( 'SELECT page_namespace,page_title,page_is_redirect FROM ' . $dbpfix . 'page WHERE page_id=?' );
my $done = 'none';
for ( @list ) {
	$sthid->execute( $_ );
	@row = $sthid->fetchrow_array;
	my @comments = ();
	my $title = $ns{$row[0]} ? $ns{$row[0]}.':'.$row[1] : $row[1];
	if ( $title && ( $row[2] == 0 ) ) {
		print "$title\n";

		# Read the article content
		$text = wikiRawPage( $wiki, $title );
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
		my $backup = $text;

		# ------ REPLACEMENT RULES --------------------------------------------------------------- #

		# Example rule: changing some record parameter names
		my $changes
			= $text =~ s/^\|\s*Foo\s*=/\| Bar =/gm
			+ $text =~ s/^\|\s*Baz\s*=/\| Biz =/gm
			+ $text =~ s/^\|\s*Buz\s*=/\| Boz =/gm;
			
		push @comments, $changes . ( $changes == 1 ? ' parameter' : ' parameters' ) . " renamed" if $changes;

		# ---------------------------------------------------------------------------------------- #

		# If article changed, write and comment
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
		if ( $text ne $backup ) {
			wikiEdit( $wiki, $title, $text, join( ', ', @comments ), 1 );
			$done = $done + 1;
			}
		}
	sleep( 0.2 );
	}

$sthid->finish;
$dbh->disconnect;
