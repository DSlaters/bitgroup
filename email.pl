#!/usr/bin/perl
use Net::IMAP::Simple::SSL;
use Net::POP3;

	# open a connection to the IMAP server
	$server = new Net::IMAP::Simple::SSL( 'organicdesign.co.nz' );

	# login
	$server->login( 'nad', '***' );
	
	# select the desired folder
	$number_of_messages = $server->select( 'Inbox' );

	# go through all the messages in the selected folder
	foreach $msg ( 1..5 ) {

		if ( $server->seen( $msg ) ) {
			print "This message has been read before...\n"
		}

		# get the message, returned as a reference to an array of lines
		$lines = $server->get( $msg );

		# print it
		print @$lines;

		# get the message, returned as a temporary file handle
		$fh = $server->getfh( $msg );
		print <$fh>;
		close $fh;

	}

	# the list of all folders
	@folders = $server->mailboxes();
#	print "folders: @folders\n";

	# create a folder
	$server->create_mailbox( 'Contacts.newfolder' );

	# rename a folder
#	$server->rename_mailbox( 'newfolder', 'renamedfolder' );

	# delete a folder
#	$server->delete_mailbox( 'renamedfolder' );

	# copy a message to another folder
   print  $server->copy( 1, 'Contacts' );

	# close the connection
	$server->quit();


###########


sub popCheck {

	# Login in to POP box
	my( $domain, $user ) = @_;
	my $loggedIn = 0;
	my $pop3 = Net::POP3->new( $domain );
	$pop3->login( $user, $::pwd4 );

	# Loop through all messages
	my $list = $pop3->list();
	my @messages = keys %$list;
	logAdd( ($#messages+1)." messages on $user\@$domain" );
	for ( @messages ) {

		# Get relevent message headers and content
		my $msg = $pop3->top( $_, 4096 );
		chomp @$msg;
		( my $to ) = grep /^to:/i, @$msg;
		if ( $to =~ /([-.&a-z0-9_]+)@([-.a-z0-9_]+)/i ) {

			( my $page, my $domain ) = ( $1, $2 );
			$to = "$page\@$domain";
			$page =~ tr/&/%/;
			( my $from ) = grep /^from:/i, @$msg;
			$from = $1 if $from =~ /([-.&a-z0-9_]+@[-&.a-z0-9_]+)/i;
			( my $subject ) = grep /^subject:/i, @$msg;
			$subject =~ s/^.+?:\s*(.*?)(\r?\n)*/$1/;

			# Couldn't forward an od addr to another od addr at zoneedit
			$page = 'user_talk%3ajewel' if $to =~ /^jewel@/;

			# Append if addressed to a talk page
			if ( $page =~ /^(\w*?_)?talk%3a/i ) {
				$) while shift @$msg;
				my $append = "\n----\n'''Email from [mailto:$from $from]''', ~~";
				$append .= "~~\n\n'''''$subject'''''\n:".join( "\n:", @$msg )."\n";
				$loggedIn = wikiLogin $::wiki, $::peer, $::pwd1 unless $loggedIn;
				wikiPageAppend $::wiki, $page, $append, $subject;
				$pop3->delete($_);
				}

			# Execute if an email command
			if ( $subject =~ /^(.+?):(.+?)\((.*?)\)\s*(.*)$/ and $1 eq $::pwd5 ) {
				spawn $2, split /\s*,\s*/, $3;
				logAdd "Executing $2";
				$pop3->delete($_);
				}

			}
		}
	$pop3->quit();
	logAdd 'Exit';
	}
