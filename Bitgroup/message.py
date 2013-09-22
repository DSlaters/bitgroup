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
	def __init__(self, msg):
		self.date = email.utils.formatdate(time.mktime(datetime.datetime.fromtimestamp(float(msg['receivedTime'])).timetuple()))
		self.toAddr = msg['toAddress']
		self.fromAddr = msg['fromAddress']
		self.subject = msg['subject'].decode('base64')
		self.body = msg['message'].decode('base64')
		return None

	def send(self):
		return None
	
	def reply(self):
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
		return None


class DataSync(BitgroupMessage):
	"""Handles the group data synchronisation for offline users"""

	def __init__(self):
		super(Invitation, self).__init__()
		return None
