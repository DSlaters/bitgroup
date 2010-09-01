#!/usr/bin/perl
#
# Copyright (C) 2009-2010 Aran Dunkley
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
use strict;

$ver    = '0.0.1'; # 2010-09-01

$log  = '/var/www/tools/Sandy/mtexim.log';
$out  = '/var/www/tools/Sandy/mtexim.out';
logAdd();
logAdd( "$::daemon-$::ver" );

my $msg = '';
logAdd( $_ ) while <STDIN>;

# Read and return content from passed file
sub readFile {
	my $file = shift;
	if ( open FH, '<', $file ) {
		binmode FH;
		sysread FH, ( my $out ), -s $file;
		close FH;
		return $out;
	}
}

# Write passed content to passed file
sub writeFile {
	my $file = shift;
	if ( open FH,'>', $file ) {
		binmode FH;
		print FH shift;
		close FH;
		return $file;
	}
}


# Output an item to the email log file with timestamp
sub logAdd {
	my $entry = shift;
	open LOGH, '>>', $::log or die "Can't open $::log for writing!";
	print LOGH localtime() . " : $entry\n";
	close LOGH;
	return $entry;
}


# Check the passed email source for messages to process
sub checkEmail {
	my $srckey = shift;
	my %args   = %{$$::sources{$srckey}};
	my $limit  = 4096;
	my $maxage = $args{maxage};

	my $server = $args{ssl} ? Net::IMAP::Simple::SSL->new( $args{host} ) : Net::IMAP::Simple->new( $args{host} );
	if ( $server ) {
		if ( $server->login( $args{user}, $args{pass} ) > 0 ) {
			logAdd( "$t Logged \"$args{user}\" into IMAP server \"$args{host}\"" );
			my $i = $server->select( $args{path} or 'Inbox' );
			logAdd( "$t $i messages to scan" );
			while ( $i > 0 ) {
				if ( my $fh = $server->getfh( $i ) ) {
					sysread $fh, ( my $content ), $limit;
					close $fh;
					$server->delete( $i ) if processMessage( $content, $t );
				}
				$i--;
			}
		} else { logAdd( "$t Couldn't log \"$args{user}\" into $args{proto} server \"$args{host}\"" ) }
		$server->quit();
	} else { logAdd( "$t Couldn't connect to $args{proto} server \"$args{host}\"" ) }
}

