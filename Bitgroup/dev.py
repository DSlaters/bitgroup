#!/usr/bin/python2.7
import os, sys, json, time, glob, re
from subprocess import Popen

class fakeBitmessage:
	"""
	A fake Bitmessage daemon for testing locally without needing the real thing running
	"""
	datapath = None  # Where the data for all dev instances is stored
	sfile = None     # Location of this instance's subscriptions file
	mfile = None     # Locations of all the messages
	mlock = None     # Lock file for accessing the messages file
	name = None      # The nickname on which all the dev instances are based

	# Local cache of the messages and subscriptions
	messages = {}
	subscriptions = []

	def __init__(self):

		app.log("Initialising fake Bitmessage API")
		# Use the original nickname as the base name for all the dev users
		self.name = app.config.get('user', 'nickname')

		# Change the data path to the program dir/.dev/nickname
		self.datapath = os.path.dirname(__file__) + '/.dev'
		if not os.path.exists(self.datapath): os.mkdir(self.datapath)
		app.datapath = self.datapath + '/' + app.user.addr

		# Define the lock file for this group of dev users and delete if exists (and we-re the first instance)
		self.mlock = self.datapath + '/.lock.' + self.name
		if app.dev == 1 and os.path.exists(self.mlock): os.remove(self.mlock)

		# Run multiple instances
		if app.dev == 1:
			for i in range(2, 1+app.devnum):
				pid = Popen([os.path.dirname(__file__) + '/main.py', 'dev', str(app.devnum), str(i)]).pid
				app.log("Started dev instance #" + str(i) + " (" + str(pid) + ")")

		# Set up message and subscription file locations - not that getSubscribers() relies on this naming convention
		self.sfile = self.datapath + '/' + app.user.addr + '/subscriptions.json'
		self.mfile = self.datapath + '/messages.' + self.name + '.json'

		# Load subscriptions
		self.loadSubscriptions()

	"""
	Store a message in a users mailbox
	"""
	def deliver(self, recipients, message):

		# If the messages are in use by another dev user, wait until they've finished
		while os.path.exists(self.mlock): time.sleep(0.1)
		
		# Create the lock file so we now have exclusive use of the messages file
		h = open(self.mlock, "w")
		h.write(str(app.dev));
		h.close()
		
		# Deliver the message to the recipients
		messages = self.loadMessages()
		for toAddr in recipients:
			if not toAddr in messages: messages[toAddr] = { 'inboxMessages': {} }
			msgID = len(messages[toAddr])
			messages[toAddr][msgID] = message
		h = open(self.mfile, "w")
		h.write(json.dumps(messages));
		h.close()

		# Remove the lock file
		os.remove(self.mlock)

	"""
	Load this dev user's subscriptions list into the local cache
	"""
	def loadSubscriptions(self):
		if os.path.exists(self.sfile):
			h = open(self.sfile, "r")
			self.subscriptions = json.loads(h.read())
			h.close()
			app.log(str(len(self.subscriptions)) + ' subscriptions loaded')
		else: self.subscriptions = []

	"""
	Save this user's subscriptions cached data into their file
	"""
	def saveSubscriptions(self):
		if len(self.subscriptions) > 0:
			h = open(self.sfile, "w")
			h.write(json.dumps(self.subscriptions));
			h.close()

	"""
	Return a list of subscribers to the passed address
	"""
	def getSubscribers(self, addr):
		users = []
		for f in glob.glob(self.datapath + '/*/subscriptions.json'):
			h = open(f, "r")
			subs = json.loads(h.read())
			h.close()
			if addr in subs: users.append(re.search('/(BM-.+?)/', f).group(1))	
		app.log(str(len(users)) + ' subscribers to ' + addr)		
		return users
		
	"""
	Read and return all dev user's messages
	"""
	def loadMessages(self):
		if os.path.exists(self.mfile):
			h = open(self.mfile, "r")
			messages = json.loads(h.read())
			h.close()
		else: messages = {}
		return messages

	"""
	The following methods are all replicas of the Bitmessage API methods
	"""
	def addSubscription(self, addr, label = None):
		k = app.user.addr
		if not k in self.subscriptions: self.subscriptions[k] = []
		self.subscriptions[k].append(addr)
		self.saveSubscriptions()

	def sendMessage(self, toAddr, fromAddr, subject, body):
		self.deliver([toAddr], {
			'toAddress': toAddr,
			'fromAddress': fromAddr,
			'subject': subject,
			'message': body
		})

	def sendBroadcast(self, fromAddr, subject, body):
		self.deliver(self.getSubscribers(fromAddr), {
			'fromAddress': fromAddr,
			'subject': subject,
			'message': body
		})

	def getAllInboxMessages(self):
		k = app.user.addr
		if not k in self.messages: self.messages[k] = { 'inboxMessages': {} }
		return json.dumps(self.messages[k])
		
	def createDeterministicAddresses(self, passwd, num):
		addr = { 'addresses': [] }
		for i in range(1, 1+num): addr['addresses'].append('BM-' + hashlib.md5(passwd + str(num)).hexdigest())
		return json.dumps(addr)
		
	def add(self, a, b):
		return a + b

