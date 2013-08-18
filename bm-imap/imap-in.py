#!/usr/bin/python2.7
import sys
import ConfigParser
import re
import smtplib
sys.path.append( '/home/odsmtp/bmwrapper' )
from bminterface import *
from incoming import *

# This script is now called directly on a cronjob and sends the retrieved Bitmessage messages to a local email address
config = ConfigParser.SafeConfigParser()
config.read(bminterface.lookupAppdataFolder() + 'keys.dat')
emailUsers = dict(config.items('emailusers'))

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

	# If the from
	print emailUsers
	toAddress = emailUsers.index(toBM) or emailUsers[0];

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



