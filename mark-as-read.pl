#!/usr/bin/perl
$sender = $ENV{SENDER};
$id = $ENV{MESSAGE_ID};
$file = "/etc/exim4/virtual.users";
if( open FH,'<', $file ) {
	sysread FH, $users, -s $file;
	close FH;
	if( $users =~ /^$sender\s*:\s*(.+?)@localhost\s*$/m ) {
		$user = $1;

		my $file = "/home/nad/eximtest";
		if( open FH,'>', $file ) {
			print FH "user: $user\nid: $id\n";
			close FH;
		}

		$id = $ENV;
		for my $msg (glob "/home/$user/Maildir/.Sent/new/*") {
			if( open FMSG,'<', $msg ) {
				sysread FMSG, $content, -s $msg;
				close FMSG;
				rename $msg, "$msg:2,S" if $content =~ /^\s*id\s*$id\s*$/m;
			}
		}
	}
}


