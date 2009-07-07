#!/usr/bin/perl
use Expect;
require( '/var/www/tools/wikid.conf' );
$server = 'foo.com';
$port = '12345';

for $dir (
	'media',
	'documents',
	'logs'
) {
	$cmd = "unison $dir ssh://$name\@$server:$port/foo/$dir -batch -force $dir";
	$exp = Expect->spawn( $cmd );
	$exp->expect(
		undef,
		[ qr/password:/ => sub { my $exp = shift; $exp->send( "$sshpass\n" ); exp_continue; } ],
		[ qr/Synchronization complete/ => sub { } ],
	);
	$exp->soft_close();
}



