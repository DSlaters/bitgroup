#!/usr/bin/perl
#
# Migrating EWG data from private to the EWG.OD wiki
#
require "wiki.pl";
require "wikid.conf";

wikiLogin( $ewgsrc, $ewguser, $ewgpass );
wikiLogin( $ewgdst, $ewguser, $ewgpass );

my $comment = "Imported by private2ewgod.pl";

# Projects
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Projects}}', 1 );
for my $title ( @titles ) {
	my $text = wikiRawPage( $ewgsrc, $title );

	&changeOrganisation;
	&changePeople;

	wikiEdit( $ewgdst, $title, $text, $comment );
}

# Issues
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Issues}}', 1 );
for my $title ( @titles ) {
	my $text = wikiRawPage( $ewgsrc, $title );

	&changeOrganisation;
	&changePeople;
	&changeIssue;

	wikiEdit( $ewgdst, $title, $text, $comment );
}

# Activities
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Activities}}', 1 );
for my $title ( @titles ) {
	my $text = wikiRawPage( $ewgsrc, $title );

	&changeOrganisation;
	&changePeople;
	&changeIssue;

	wikiEdit( $ewgdst, $title, $text, $comment );
}


# Change first names to full names
sub changePeople {
	$text =~ s|Aran(?!= Dunkley)|Aran DUnkley|g;
	$text =~ s|Jack(?!= Henderson)|Jack Henderson|g;
	$text =~ s|Milan(?!= Holzapfel)|Milan Holzapfel|g;
	$text =~ s|Rob(?!=ert)|Robert Carter|g;
	$text =~ s|Dana(?!= Darwin)|Dana Darwin|g;
	$text =~ s|Sven|Marcus Davy|g;
}

# Change organisation
sub changeOrganisation {
	$text =~ s|kiwigreen limited|Earthwise Group Ltd|ig;
}

# Change issues
sub changeIssue {
	$text =~ s|(?<=\{\{)Issue(?=\W)|Task|;
	$text =~ s|^(\s*\|\s*)Issue(\s*=)|$1Task $2|mg;
}
