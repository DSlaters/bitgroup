#!/usr/bin/perl
use Expect;
require( '/var/www/tools/wikid.conf' );
$bak_user = $name unless defined $bak_user;

for $dir ( @bak_paths ) {
	$cmd = "unison $dir ssh://$bak_user\@$bak_server$dir -batch -force $dir -log -logfile /var/log/syslog";
	$exp = Expect->spawn( $cmd );
	$exp->expect(
		undef,
		[ qr/password:/ => sub { my $exp = shift; $exp->send( "$bak_pass\n" ); exp_continue; } ],
		[ qr/Synchronization complete/ => sub { } ],
	);
	$exp->soft_close();
}



