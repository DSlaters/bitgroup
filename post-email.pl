#!/usr/bin/perl
#
# Reads an email file given as the first arg, extracts the headers and text
# and posts them to the URL in the second arg
#
# Copyright (C) 2008-2010 Aran Dunkley
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
# Dependencies: libemail-mime-perl
#
use Email::MIME;
use HTTP::Request;
use LWP::UserAgent;
use utf8;
use Encode;
use strict;
my $file = $ARGV[0];
my $post = $ARGV[1];

# Read in the email file and remove it
die "Couldn't read email file" unless open FH, '<', $file;
read FH, my $email, -s $file;
close FH;
unlink $file;

# Test if lines are doubled up and fix if so
$email =~ s/\n\n/\n/g if $email =~ /Message-ID: \S+\n\n/s;

# Extract the useful header portion of the message
my $id      = $1 if $email =~ /^message-id:\s*<(.+?)>\s*$/mi;
my $date    = $1 if $email =~ /^date:\s*(.+?)\s*$/mi;
my $to      = $1 if $email =~ /^to:\s*(.+?)\s*$/mi;
my $from    = $1 if $email =~ /^from:\s*(.+?)\s*$/mi;
my $subject = $1 if $email =~ /^subject:\s*(.+?)\s*$/im;

# Support for MIME encoded
$from    = decode( "MIME-Header", $from );
$to      = decode( "MIME-Header", $to );
$subject = decode( "MIME-Header", $subject );

# Ensure the utf8 encoding
# FIXME: guess the original encoding!
Encode::from_to( $from,    "iso-8859-2", "utf8" ) if !utf8::is_utf8( $from );
Encode::from_to( $to,      "iso-8859-2", "utf8" ) if !utf8::is_utf8( $to );
Encode::from_to( $subject, "iso-8859-2", "utf8" ) if !utf8::is_utf8( $subject );

# Extract only real email address portion
$from = $1 if $from =~ /<(.+?)>$/;
$to = $1 if $to =~ /<(.+?)>$/;

# Loop through parts to find body
my $plain_body = "";
my $other_body = "";
Email::MIME->new( $email )->walk_parts( sub {
	my( $part ) = @_;
	unless( $part->content_type =~ /\bname="([^\"]+)"/ ) {
		if( $part->content_type =~ m!^text/! ) { $plain_body .= $part->body_str }
		else { $other_body .= $part->body unless $part->body =~ /This is a multi-part message in MIME format/i }
	}
} );

# Use alternative body if no normal body found
my $body = $plain_body;
$body = $other_body if $body =~ /^\s*$/;
$body =~ s/\r//g;

# Don't check SSL certs
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

# Set up a user agent to do the post
my $ua = LWP::UserAgent->new(
	cookie_jar => {},
	agent      => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; it; rv:1.8.1.14)',
	from       => 'post-email.pl@organicdesign.co.nz',
	timeout    => 10,
	max_size   => 100000
);

# Put the data into a form hash ready for posting
my %form = (
	id      => $id,
	date    => $date,
	from    => $from,
	to      => $to,
	subject => $subject,
	body    => $body
);

# Post the data to the given url
my $res = $ua->post( "$post&action=postemail", \%form );
print "Error: " . $res->message . " (" . $res->code . ")\n" if $res->is_error();
print $res->content if $res->is_success;
