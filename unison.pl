#!/usr/bin/perl
use Expect;
require( '/var/www/tools/wikid.conf' );
require( '/var/www/tools/wiki.pl' );
$bak_user = $name unless defined $bak_user;
$wikiuser = $name unless defined $wikiuser;

for $dir ( @bak_paths ) {
	$out .= qx( du -sh $dir ) . "\n";
	$cmd = "unison $dir ssh://$bak_user\@$bak_server$dir -batch -force $dir -log -logfile /var/log/syslog";
	$exp = Expect->spawn( $cmd );
	$exp->expect(
		undef,
		[ qr/password:/ => sub { my $exp = shift; $exp->send( "$bak_pass\n" ); exp_continue; } ],
		[ qr/Synchronization complete/ => sub { } ],
	);
	$exp->soft_close();
}

if ( defined $wikipass ) {
	wikiLogin( $wiki, $wikiuser, $wikipass );
	my $text = '';
	$text .= qx( du -sh $_ ) . "\n" for @stat_paths;
	$text = "<pre>\n$text</pre>";
	wikiEdit( $wiki, 'Template:FileSystemUsage', $text, 'Update usage statistics' );
}
