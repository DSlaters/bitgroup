#!/usr/bin/python2.7
import sys
sys.path.append( '~/bmwrapper' )
from incoming.py import *

# This script is now called directly on a cronjob and sends the retrieved Bitmessage messages to a local email address
config = ConfigParser.SafeConfigParser()
config.read(keysPath)
emailAddresses = config.items('Email addresses')

# Loop through the Bitmessage messages
msgCount = bminterface.listMsgs()
print "%i messages to parse" % (msgCount)
for msgID in range(msgCount):
	print "Parsing msg %i" % (msgID+1)

	# Get the Bitmessage message
	dateTime, toAddress, fromAddress, subject, body = bminterface.get(msgID)

	# Convert the To and From addresses to raw Bitmessage addresses
	print re.match(r'^(.+)@', toAddress).group(1)

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



