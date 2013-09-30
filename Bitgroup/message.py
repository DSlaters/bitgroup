import json
import datetime
import time
import email.utils
import re
import inspect

class Message(object):
	"""
	Class representing a Bitmessage message
	"""
	date     = None
	toAddr   = None
	fromAddr = None
	subject  = None
	body     = None

	# This is set if the body content should be encrypted when sent
	passwd = None

	# This is set by syb-classes if data cannot be decoded, or it's found to be invalid
	invalid = False

	"""
	Determine the correct class for the message and instantiate it
	"""
	def __new__(self, msg):
		if self.__class__.__name__ == 'Message':

			# Determine what class it should be
			cls = Message.getClass(msg)
			if cls.__class__.__name__ != 'Message':

				# Change the Message class an instance of the returned class
				self = cls(msg)

				# If the instance has determined it's not a valid message of it's type, return None
				if bgmsg.invalid: return None

		return object.__new__(self, msg)

	"""
	Initialise the Bitmessage message containing all the message attributes and data
	"""
	def __init__(self, msg):
		self.date = email.utils.formatdate(time.mktime(datetime.datetime.fromtimestamp(float(msg['receivedTime'])).timetuple()))
		self.toAddr = msg['toAddress']
		self.fromAddr = msg['fromAddress']
		self.subject = msg['subject'].decode('base64')
		self.body = msg['message'].decode('base64')
		return None

	"""
	Check if the passed BM-message is one of ours and if so what Message sub-class it is
	- returns a class that can be used for instatiation, e.g. bg_msg = getMessageClass(bm_msg)(bm_msg)
	"""
	@staticmethod
	def getClass(msg):
		subject = msg['subject'].decode('base64')
		match = re.match(app.name + "-([0-9.]+):(\w+) ", subject)
		if match:
			c = match.group(2)
			if c in globals():
				if Message in inspect.getmro(globals()[c]): return globals()[c]
			print "Class '" + c + "' is not a Message sub-class"
		return Message

	"""
	Set the current message's class in the subject line for the recipient
	"""
	def setClass(cls):
		self.subject = app.title + ': ' + cls + ' ' + app.msg('bg-msg-subject')

	"""
	Send the message
	"""
	def send(self):
		subject = self.subject.encode('base64')

		# Encode the body to base64, also encrypt first if a passwd is set
		body = self.body
		if self.passwd: body = app.encrypt(body, self.passwd)
		body = body.encode('base64')

		# Do the actual sending
		if self.toAddr: app.api.sendMessage(toAddr, fromAddr, subject, body)
		else: app.api.sendBroadcast(fromAddr, subject, body)

	"""
	Reply to the messge
	"""
	def reply(self): pass

	"""
	Read the messages from Bitmessage and update the passed local mailbox with Message instances of the correct sub-class
	TODO: this just reads all messages and replaces all in the local box, it should update not replace
	"""
	@staticmethod
	def getMessages(mailbox):
		if mailbox == None:
			messages = json.loads(app.api.getAllInboxMessages())
			mailbox = []
			for msgID in range(len(messages['inboxMessages'])):
				mailbox.append(Message(messages['inboxMessages'][msgID]))
			print str(len(mailbox)) + ' messages retrieved.'


class BitgroupMessage(Message):
	"""
	An "abstract" class representing a Bitgroup message that extends the basic Bitmessage message to exhibit properties
	"""

	# The decoded data of the message content
	data = None

	# The group the message is to
	group = None

	def __init__(self, msg):

		# Only instantiate base-class and decode the body if it's an incoming message
		if msg.__class__.__name__ == 'dict':
			Message.__init__(self, msg)

			# Set the message's group instance from the To address
			for g in app.groups:
				if g.prvaddr == self.toAddr:
					self.group = Group(self.toAddr)

			# Bail if we don't have an instance for this group
			# - this could only happen if we're subscribed to a group's private address that we're not a member of
			if self.group == None:
				print "No valid data found in message content!"
				self.invalid = True
				return None

			# Decode the body data (first try as raw JSON, if not try decrypting it with the group passwd)
			try: self.data = json.loads(self.body)
			except:
				try: self.data = json.loads(app.decrypt(self.body, self.group.passwd))
				except:
					print "No valid data found (or couldn't decrypt it) in message content!"
					self.invalid = True
					return None

		# It's an outgoing message,
		else:

			# Set the subject line to the message's class to indicate that it's to be processed by a Bitgroup app
			self.setClass(self.__class__.__name__)

		return None

	"""
	The send message method first encodes the data into the body before calling the base-class's send method
	"""
	def send(self):

		# Set the body to the JSON encoded data
		self.body = json.dumps(self.data)

		# Call the parent class's send method
		Message.send(self, msg)


class Invitation(BitgroupMessage):
	"""
	Handles the Bitgroup invitation workflow
	"""

	def __init__(self, msg):
		BitgroupMessage.__init__(self, msg)
		return None

	def accept(self): pass


class Changes(BitgroupMessage):
	"""
	Handles the group data synchronisation for offline users
	"""

	group = None
	lastSync = 0

	def __init__(self, msg):
		BitgroupMessage.__init__(self, msg)

		# If the passed arg is a group, set the message up as a broadcast to the members
		if msg.__class__.__name__ == 'Group':
			self.group = msg
			self.fromAddr = group.prvaddr

			# The message will be broadcast to the members
			self.toAddr = None

			# The content will be encrypted with the groups shared key
			self.passwd = self.group.passwd

			# Get the changes since the last changes for this group were sent
			ts = this.lastSync
			self.data = self.group.changes(ts)
			this.lastSync = app.timestamp()

		return None


class Presence(BitgroupMessage):
	"""
	TODO: Broadcasts presence information for updating members online status
	"""

	def __init__(self, msg):
		BitgroupMessage.__init__(self, msg)
		
		# If the message is intantiate with a group as parameter, this is an outgoing presence message
		if msg.__class__.__name__ == 'Group':
			self.group = msg
			self.fromAddr = group.prvaddr

			# The message will be broadcast to the members
			self.toAddr = None

			# The content will be encrypted with the groups shared key
			self.passwd = self.group.passwd

			data = {
				'peer': app.peerID,
				'addr': app.peerIP,
				'port': app.server.port
				'last': # timestamp of last data
			}

		# Otherwise it's an incoming presence message from a newly connected peer
		else:

			# The presence message should consist of just the group BM address, and an encrypted payload
			if not 'group' in self.data:
				self.invalid = true
				print "No group specified in Presence data"

			# check if its one of the groups we have
			group = Group(

			# if so, instantiate it and 
				
				
				

			# Update the peer info with the new peer's data
			app.server.peerUpdateInfo(self.data)

			# If we are the group server,
			if self.group.server:

				# respond with dataSince and member online info
				
				# open a socket to the client
				pass

		return None
