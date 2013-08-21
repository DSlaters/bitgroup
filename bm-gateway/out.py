#!/usr/bin/python2.7
# Copyright (C) 2013 Aran Dunkley
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
import os
import sys
import re
import ConfigParser
from email.utils import parseaddr

# Get dir containing the code
path = os.path.dirname(os.path.dirname(__file__))

# Import modules from bmwrapper (expected to be in the same dir as bm-imap)
sys.path.append( path + '/bmwrapper' )
from bminterface import *
from outgoing import *

# Get the mappings of email addresses to Bitmessage addresses
config = ConfigParser.SafeConfigParser()
config.read(os.path.dirname(__file__) + '/.config')
gateway = config.get('settings','gateway')
emails = dict(config.items('addresses'))

# Extend the outgoingServer class but with a null constructor so that no server gets started
class outgoingGateway(outgoingServer):
	def __init__(self):
		return None

# The email is sent to STDIN by the local mailserver's delivery filter
data = '';
for line in sys.stdin:

	# If the To field is one of the local addresses, return from the script with a message
	if re.match('To:', line) and parseaddr(line)[0] in emails.values():
		sys.exit('You cannot send to local users via the Bitmessage network.')
	
	# Map the From field to one of the Bitmessage addresses in the config file
	if re.match('From:', line):
		fromAddress = parseaddr(line)[1]
		fromBM = emails.get(fromAddress, emails.values()[0])
		line = 'From: ' + fromBM + '@bm.addr\n'

	data += line

# Call the process_message method on the email data
outgoingGateway().process_message(None, None, None, data)
