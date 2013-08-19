#!/usr/bin/python2.7
import os
import sys
import re
import email.parser, email.header

# Get username and home dir
#currentUser = os.getlogin()
currentUser = 'odsmtp'

# Import modules from bmwrapper
sys.path.append( '/home/' + currentUser + '/bmwrapper' )
from bminterface import *
from outgoing import *

# Extend the outgoingServer class but with a null constructor so that no server gets started
class imapOut(outgoingServer):
	def __init__():

# Call the process_message method on the data received from our external email server on STDIN
imapOut().process_message(None, None, None, sys.stdin.read())
