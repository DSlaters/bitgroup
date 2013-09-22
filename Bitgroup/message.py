import json
import datetime
import time
import email.utils

class Message:
	"""Class representing a Bitmessage message"""

	date     = None
	toAddr   = None
	fromAddr = None
	subject  = None
	body     = None

	# Create a local instance of the Bitmessage message containing all the message attributes and data
	def __init__(self, app, msgID):
		if app.messages == None: app.messages = json.loads(app.api.getAllInboxMessages())
		self.date = email.utils.formatdate(time.mktime(datetime.datetime.fromtimestamp(float(app.messages['inboxMessages'][msgID]['receivedTime'])).timetuple()))
		self.toAddr = app.messages['inboxMessages'][msgID]['toAddress']
		self.fromAddr = app.messages['inboxMessages'][msgID]['fromAddress']
		self.Subject = app.messages['inboxMessages'][msgID]['subject'].decode('base64')
		self.body = app.messages['inboxMessages'][msgID]['message'].decode('base64')
		return None


class BitgroupMessage(Message):
	"""An abstract class that extends the basic Bitmessage message to exhibit properties"""

	data = None

	def __init__(self):

		# Call Message's constructor first
		super(BitgroupMessage, self).__init__()

		# Decode the body data
		self.data = json.loads(self.body)
		
		return None


class Invitation(BitgroupMessage):
	"""Handles the Bitgroup invitation workflow"""

	def __init__(self):
		super(Invitation, self).__init__()
		return None

	def accept(self):


class DataSync(BitgroupMessage):
	"""Handles the group data synchronisation for offline users"""

	def __init__(self):
		super(Invitation, self).__init__()
		return None
