#!/usr/bin/perl
#
# Copyright (C) 2010 Aran Dunkley and others.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html
#
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

