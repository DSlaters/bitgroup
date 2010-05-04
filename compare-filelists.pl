#!/usr/bin/perl

%files1 = ();
%files2 = ();

open FH, '<', 'ls-en-images-local.txt';
while (<FH>) {
	$path = $1 if /^.*?(images.*):\s*$/;
	$files2{"$path/$1"} = 1 if /^\s*(.+\..{2,})\s*$/;
}
close FH;

open FH, '<', 'ls-en-images.txt';
while (<FH>) {
	$path = $1 if /^.*?(images.*):\s*$/;
	$files1{"$path/$1"} = 1 if /^\s*(.+\..{2,})\s*$/ and not defined $files2{"$path/$1"};
}
close FH;

for ( keys %files1 ) {
	print ((++$i) . " $_\n") unless /^images\/(deleted|thumb)/;
#	print "$_\n" unless /^images\/(deleted|thumb)/;
}
