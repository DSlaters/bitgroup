#!/usr/bin/python2.7
import os
import sys
import ConfigParser
import re
import smtplib

# Get username and home dir
currentUser = os.getlogin()

# Import modules from bmwrapper
sys.path.append( '/home/' + currentUser + '/bmwrapper' )
from bminterface import *
from incoming import *

# This script is now called directly on a cronjob and sends the retrieved Bitmessage messages to a local email address
config = ConfigParser.SafeConfigParser()
config.read(bminterface.lookupAppdataFolder() + 'keys.dat')
users = dict(config.items('emailusers'))

# Loop through the Bitmessage messages
msgCount = bminterface.listMsgs()
print "%i messages to parse" % (msgCount)
for msgID in range(msgCount):
	print "Parsing msg %i" % (msgID+1)

	# Get the Bitmessage message
	dateTime, toAddress, fromAddress, subject, body = bminterface.get(msgID)

	# Get the To and From raw Bitmessage addresses
	toBM = re.match(r'^(.+)@', toAddress).group(1)
	fromBM = re.match(r'^(.+)@', fromAddress).group(1)

	# Find the user in the list that has the matching Bitmessage address, or use first user if none match
	toAddress = users.keys()[users.values().index(toBM if toBM in users.values() else 0)] + '@localhost'

	# Format the email addresses to use the Bitmessage address as the friendly name and compose the message
	toAddress = toBM + ' <' + toAddress + '>'
	fromAddress = fromBM + ' <' + currentUser + '@localhost>'
	msg = makeEmail(dateTime, toAddress, fromAddress, subject, body)

	# Send the message to the local address
	try:
		smtpObj = smtplib.SMTP('localhost')
		smtpObj.sendmail(fromAddress, 'nad@localhost', msg)
		print "Successfully forwarded to local email address"
	except SMTPException:
		print "Error: unable to forward to local email address"

	# Delete the message from Bitmessage
	#bminterface.markForDelete(msgID)

bminterface.cleanup()



