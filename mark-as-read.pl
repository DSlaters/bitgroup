#!/usr/bin/perl
$sender = $ENV{SENDER};
$id = $ENV{MESSAGE_ID};
$file = "/etc/exim4/virtual.users";
if( open FH,'<', $file ) {
	sysread FH, $users, -s $file;
	close FH;
	if( $users =~ /^$sender\s*:\s*(.+?)\@localhost\s*$/m ) {
		$user = $1;
		$id = $ENV;
		for my $msg (glob "/home/$user/Maildir/.Sent/new/*") {
			print FH "$msg\n";
			if( open FMSG,'<', $msg ) {
				sysread FMSG, $content, 600;
				close FMSG;
				if( $content =~ /\s$id\s/s ) {
					rename $msg, "$msg:2,S";
				}
			}
		}
	}
}


