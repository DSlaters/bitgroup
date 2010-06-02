#!/usr/bin/perl
use Net::IMAP::Simple::SSL;
use Net::POP3;

# Takes named parameters: proto, host, path, user, pass, from, to, subject, content
# - proto is "POP3" or "IMAP"
# - host is IP or domain
# - path is the folder to get the messages from
# - from,to,subject,content are optional regular exression filters
sub emailGetMessages {
	my %args = (@_);
	my $server;

	# Connect to POP3 server and login
	if ( $args{proto} eq 'POP3' ) {
		$server = Net::POP3->new( $args{host} );
		$server->login( $args{user}, $args{pass} );
	}

	# Connect to IMAP server and login
	elsif ( $args{proto} eq 'IMAP' ) {	
		$server = new Net::IMAP::Simple::SSL( $args{host} );
		$server->login( $args{user}, $args{pass} );
		$number_of_messages = $server->select( $args{path} or 'Inbox' );
	}
	
	else { die "Unsupported email protocol!" }




		
	#pop3 message loop
		my $list = $pop3->list();
		my @messages = keys %$list;		



	# imap message loop
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


	# Loop through all messages

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
