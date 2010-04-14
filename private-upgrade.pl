#!/usr/bin/perl
#
# Upgrading private.od to the EWG state
#
require "wiki.pl";
require "wikid.conf";

$wiki = 'https://private.organicdesign.co.nz/wiki/index.php';

wikiLogin( $wiki, $wikiuser, $wikipass );

my $comment = "Updated by private-upgrade.pl";

# Projects
my @titles = wikiParse( $wiki, '{{#dpl:uses=Template:Project}}', 1 );
for my $title ( @titles ) {
	$text = wikiRawPage( $wiki, $title );

	&changeOrganisation;
	&changePeople;

	wikiEdit( $wiki, $title, $text, $comment );
}

# Issues
my @titles = wikiParse( $wiki, '{{#dpl:uses=Template:Issue}}', 1 );
for my $title ( @titles ) {
	$text = wikiRawPage( $wiki, $title );

	&changeOrganisation;
	&changePeople;
	&changeIssue;

	wikiEdit( $wiki, $title, $text, $comment );
}

# Activities
my @titles = wikiParse( $wiki, '{{#dpl:uses=Template:Activity}}', 1 );
my @titles2 = wikiParse( $wiki, '{{#dpl:uses=Template:Activity|offset=500}}', 1 );
for my $title ( @titles, @titles2 ) {
	$text = wikiRawPage( $wiki, $title );

	&changeOrganisation;
	&changePeople;
	&changeIssue;

	wikiEdit( $wiki, $title, $text, $comment );
}


# Change first names to full names
sub changePeople {
	$text =~ s/Peder( Halseid)*/Peder Halseid/g;
}

# Change organisation
sub changeOrganisation {
	#$text =~ s/kiwigreen (limited|ltd)/Earthwise Group Ltd/ig;
}

# Change issues
sub changeIssue {
	$text =~ s/(?<=\{\{)Issue(?=\W)/Task/;
	$text =~ s/^(\s*\|\s*)Issue\s*=/$1Task =/mg;
}
