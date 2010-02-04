#!/usr/bin/perl
#
# Migrating EWG data from private to the EWG.OD wiki
#
require "wiki.pl";
require "wikid.conf";

@titles = wikiParse( $ewgsrc, '{{#dpl:category=NZKIWIGREEN Limited}}', 1 );

for my $title ( @titles ) {
	
	print "$title\n";
	
}
