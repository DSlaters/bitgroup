#!/usr/bin/perl
# Subroutines for DCS linking system called by wikid.pl

use DBI;
$::dbname = 'svn';
$::dbuser = 'root';
$::dbpass = 'pPq6r94';
$::dbpre = '';
$::db = DBI->connect( "DBI:mysql:$::dbname", $::dbuser, $::dbpass );

# Overrides default event
sub onRevisionInsertComplete {
	my $id      = $::data =~ /'mId'\s*=>\s*([0-9]+)/       ? $1 : '';
	my $page    = $::data =~ /'mPage'\s*=>\s*([0-9]+)/     ? $1 : '';
	my $user    = $::data =~ /'mUserText'\s*=>\s*'(.+?)'/  ? $1 : '';
	my $parent  = $::data =~ /'mParentId'\s*=>\s*([0-9]+)/ ? $1 : '';
	my $comment = $::data =~ /'mComment'\s*=>\s*'(.+?)'/   ? $1 : '';
	my $title   = $::data =~ /'title'\s*=>\s*'(.+?)'/      ? $1 : '';
	if ( $page and $user ) {
		
		if ( $title eq 'MediaWiki:TermsList' ) {
			print $::ircsock "PRIVMSG $ircchannel :TermsList changed by $user\n";
		}
		
		else {
		
			if ( lc $user ne lc $wikiuser ) {
				my $action = $parent ? 'changed' : 'created';
				my $utitle = $title;
				$title  =~ s/_/ /g;
				$utitle =~ s/ /_/g;
				print $::ircsock "PRIVMSG $ircchannel :\"$title\" $action by $user, checking TermsList\n";
			}
			
		}
	} else { logAdd( "Not processing (page='$page', user='$user', title='$title')" ) }
}

# Parse some article text and update terms links
sub parseContent {
	my $text = shift;
	
	# read MediaWiki:TermsList if not already read in
	$::TermsList = '' unless defined $::TermsList;
	$::TermsList = wikiRawPage( $::wiki, 'MediaWiki:TermsList' ) unless $::TermsList;

	#while ( $row = $dbr->fetchRow( $res ) ) $terms[] = str_replace( '_', ' ', $row[0] );
	#$this->terms = join( '|', $terms );
	#$text = preg_replace_callback( "|<p>.+?</p>|s", array( $this, 'replaceTerms' ), $text );

	# Loop through terms from longest to shortest
	for my $term ( sort { length($b) <=> length($a) } keys %terms ) {
		my $target = $terms($term};
		if ( $target ) {
			# check for each term in unlinked form for ones needing terms
		} else {
			# check for linked ones to "undo" if marked as not linking (no target)
		}
	}

	return $text;
}

# Scan all articles in all wikis and update links in each
sub scanArticles {

	# Clear the TermsList cache first
	$::TermsList = '';

	# Get ID's of all articles that are not in MediaWiki namespace
	my @list = ();
	my $sth = $::db->prepare( 'SELECT page_id FROM ' . $::dbpre . 'page WHERE page_namespace != 8' );
	$sth->execute();
	push @list, @row[0] while @row = $sth->fetchrow_array;
	$sth->finish;

	# Loop through list
	my $sthid = $::db->prepare( 'SELECT page_namespace,page_title,page_is_redirect FROM ' . $::dbpre . 'page WHERE page_id=?' );
	my $done = 'none';
	for ( @list ) {
		$sthid->execute( $_ );
		@row = $sthid->fetchrow_array;
		my @comments = ();
		my $title = $ns{$row[0]} ? $ns{$row[0]}.':'.$row[1] : $row[1];
		if ( $title && ( $row[2] == 0 ) ) {
			print "$title\n";
			parseContent( $text );
		}
	}
}

scanArticles();

1;
