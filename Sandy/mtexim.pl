#!/usr/bin/env perl

$::ver    = '0.0.1'; # 2010-09-01
$::log  = '/var/www/tools/Sandy/mtexim.log';
$::out  = '/var/www/tools/Sandy/mtexim.out';
logAdd();
logAdd( "$::daemon-$::ver" );

my $msg = '';
logAdd( $_ ) while <STDIN>;

exit(0);

sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}

