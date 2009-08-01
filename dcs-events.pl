# Subroutines for DCS linking system called by wikid.pl

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
	return $text;
}

# Scan all articles in all wikis and update links in each
sub scanArticles {
}

1;
