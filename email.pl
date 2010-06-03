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
	my $maxsize = 4096;
	my @messages = ();

	# POP3
	if ( $args{proto} eq 'POP3' ) {

		# Connect & login
		$server = Net::POP3->new( $args{host} );
		$server->login( $args{user}, $args{pass} );
		
		# Process messages
		my @list = keys %{ $server->list() };
		for ( @list ) {
			my $content = join "\n", @{ $server->top( $_, $maxsize ) };
			push @messages, emailProcessMessage( $content, \@args );
		}
		
		# Close
		$server->quit();
	}

	# IMAP
	elsif ( $args{proto} eq 'IMAP' ) {
		
		# Connect & login
		$server = new Net::IMAP::Simple::SSL( $args{host} );
		$server->login( $args{user}, $args{pass} );
		
		# Process messages
		$count = $server->select( $args{path} or 'Inbox' );
		for ( 1 .. $count ) {
			$fh = $server->getfh( $_ );
			sysread $fh, ( my $content ), $maxsize;
			close $fh;
			push @messages, emailProcessMessage( $content, \@args );
		}

		# Close
		$server->quit();
	}
	
	else { die "Unsupported email protocol!" }

	return @messages;
}

# Returns passed message as an array reference if its attributes match the rules in @args
sub emailProcessMessage {
	my $content = shift;
	my @args    = @{ shift };
	my @return  = undef;
	my $to      = $1 if $content =~ /^to:\s*(.+?)\s*$/mi;
	my $from    = $1 if $content =~ /^from:\s*(.+?)\s*$/mi;
	my $subject = $1 if $content =~ /^subject:\s*(.+?)\s*$/im;

	# Test message against @args regex's
	if ( matches ) {
		@return = \( $from, $to, $subject, $content );
	}

	return @return;
}

