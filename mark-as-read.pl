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
			print FH "user: $user\n";
			close FH;
		}

		$id = $ENV;
		for(glob "/home/$user/Maildir/.Sent/new/*") {
			if( open FMSG,'<', $_ ) {
				sysread FMSG, $content, -s $_;
				close FMSG;
				rename $_, $_.':2,S' if $content =~ /^\s*id\s*$id\s*$/m;
			}
		}
	}
}


