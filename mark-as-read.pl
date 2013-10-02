#!/usr/bin/perl

my $file = "/home/nad/eximtest";
if ( open FH,'>', $file ) {
	print FH $ENV{LOGNAME};
	close FH;
}

for(glob "/home/*/Maildir/.Sent/new/*") {
	rename $_, $_.':2,S' unless /:/
}
