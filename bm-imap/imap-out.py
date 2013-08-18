#!/usr/bin/python2.7
import os
import sys
import re
import email.parser, email.header

# Get username and home dir
currentUser = os.getlogin()
currentUser = 'odsmtp'

# Import modules from bmwrapper
sys.path.append( '/home/' + currentUser + '/bmwrapper' )
from bminterface import *
from outgoing import *

# The email is passed to STDIN
#my @input = <STDIN>;

# The URL to post the extracted data to is a program argument
#my $post = $ARGV[0];

# Extract the useful header portion of the message
#my $id      = $1 if $email =~ /^message-id:\s*<(.+?)>\s*$/mi;
#my $date    = $1 if $email =~ /^date:\s*(.+?)\s*$/mi;
#my $to      = $1 if $email =~ /^to:\s*(.+?)\s*$/mi;
#my $from    = $1 if $email =~ /^from:\s*(.+?)\s*$/mi;
#my $subject = $1 if $email =~ /^subject:\s*(.+?)\s*$/im;

foo = outgoingServer()

