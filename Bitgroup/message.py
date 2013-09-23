import json
import datetime
import time
import email.utils
import re
import inspect

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


	# Check if the passed BM-message is one of ours and if so what Message sub-class it is
	# - returns a class that can be used for instatiation, e.g. bg_msg = getMessageClass(bm_msg)(bm_msg)
	@staticmethod
	def getClass(msg):
		subject = msg['subject'].decode('base64')
		#subject = "Bitgroup-0.00:Invitation "
		match = re.match("Bitgroup-([0-9.]+):(\w+) ", subject)
		if match:
			c = match.group(2)
			if c in globals():
				if Message in inspect.getmro(globals()[c]): return globals()[c]
			print "Class '" + c + "' is not a Message sub-class"
		return Message

	# Send the message
	def send(self): pass

	# Reply to the messge
	def reply(self): pass


class BitgroupMessage(Message):
	"""An abstract class that extends the basic Bitmessage message to exhibit properties"""

	# The decoded data of the message content
	data = None

	# This is set if data cannot be decoded, or the sub-class finds the data content invalid
	invalid = False

	def __init__(self, msg):
		Message.__init__(self, msg)

		# Decode the body data
		try: self.data = json.loads(self.body)
		except:
			print "No valid data found in message content!"
			self.invalid = True
		
		return None


class Invitation(BitgroupMessage):
	"""Handles the Bitgroup invitation workflow"""

	def __init__(self, msg):
		BitgroupMessage.__init__(self, msg)
		return None

	def accept(self): pass


class DataSync(BitgroupMessage):
	"""Handles the group data synchronisation for offline users"""

	def __init__(self):
		BitgroupMessage.__init__(self, msg)
		return None
