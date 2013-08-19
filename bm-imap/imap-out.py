#!/usr/bin/python2.7
import os
import sys
import re
import email.parser, email.header

# Get username and home dir
currentUser = os.getlogin()
currentUser = 'odsmtp'

# The email data is passed to STDIN
data = sys.stdin.readlines()

# Import modules from bmwrapper
sys.path.append( '/home/' + currentUser + '/bmwrapper' )
from bminterface import *
from outgoing import *

# Start up an instance of the outgoing server based on out dummy SMTPserver class
dummy = outgoingServer()

# Now we can call its process_message method on the data received from our external email server
dummy.process_message(dummy, None, None, None, data)
