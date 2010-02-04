#!/usr/bin/perl
#
# Migrating EWG data from private to the EWG.OD wiki
#
require "wiki.pl";
require "wikid.conf";

wikiLogin( $ewgsrc, $ewguser, $ewgpass );
wikiLogin( $ewgdst, $ewguser, $ewgpass );

# Projects
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Projects}}', 1 );
for my $title ( @titles ) {
	
	# Change Organisation from KG to EWG
	
	# Change Leader and Members to full names
	
}

# Tasks
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Issues}}', 1 );
for my $title ( @titles ) {
	
	# Change Organisation from KG to EWG
	
	# Change AssignedTo and Attention to full names
	
}

# Activities
my @titles = wikiParse( $ewgsrc, '{{#dpl:category=KIWIGREEN Limited|category=Activities}}', 1 );
for my $title ( @titles ) {
	
	# Change Organisation from KG to EWG
	
	# Change Participants to full names
	
	# Change Issue parameter to Task
	
}


# Change first names to full names
sub fullNames {
}
