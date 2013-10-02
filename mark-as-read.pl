#!/usr/bin/perl

my $file = '/home/nad/eximtest';
if( open FH,'>>', $file ) {
	print FH $ENV{SENDER} . "\n";
	print FH getpwuid($<) . "\n";
	print FH $ENV{MESSAGE_ID} . "\n\n";
	close FH;
}

for(glob "/home/*/Maildir/.Sent/cur/*") { rename $_, $_.'S' if /2,$/ }
