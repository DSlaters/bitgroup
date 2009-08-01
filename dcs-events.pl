# Subroutines for DCS linking system called by wikid.pl

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
	
	# read MediaWiki:TermsList
	
	# sort
	
	# loop thru them
	
		# if ( target ) 
	
		# check for each term in unlinked form for ones needing terms
		
		# check for linked ones to "undo" if marked as not linking (no target)
	
	return $text;
}

# Scan all articles in all wikis and update links in each
sub scanArticles {

	# Build a list of all articles in the wiki
	my $sth = $::db->prepare( 'SELECT page_id FROM ' . $::dbpre . 'page WHERE page_title = "Zhconversiontable"' );
	$sth->execute();
	my @row = $sth->fetchrow_array;
	$sth->finish;
	my $first = $row[0]+1;
	my $sth = $dbh->prepare( 'SELECT page_id FROM ' . $::dbpre . 'page ORDER BY page_id DESC' );
	$sth->execute();
	@row = $sth->fetchrow_array;
	$sth->finish;
	my $last = $row[0];
	@list = ( $first .. $last );

	# Loop through all articles
	my $sthid = $dbh->prepare( 'SELECT page_namespace,page_title,page_is_redirect FROM ' . $dbpre . 'page WHERE page_id=?' );
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

1;
