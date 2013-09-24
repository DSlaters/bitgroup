import __builtin__
import os
import sys
import re
import http
import xmlrpclib
import json
import time
import datetime
from user import *
from group import *
from message import *

class App:
	"""The main top-level class for all teh functionality of the Bitgroup application"""

	name = None
	inbox = None
	user = {}
	groups = {}
	maxage = 600000 # Expiry time of queue items in milliseconds
	i18n = {}       # i18n interface messages loaded from interface/i18n.json

	state = {}      # Dynamic application state information
	stateAge = 0    # Last time the dynsmic application state data was updated

	def __init__(self, config, configfile):

		__builtin__.app = self   # Make the app a "superglobal"
		self.name = 'Bitgroup'
		self.version = '0.0.0'
		self.docroot = os.path.dirname(__file__) + '/interface'
		self.config = config
		self.configfile = configfile

		# Set the location for application data and create the dir if it doesn't exist
		self.datapath = os.getenv("HOME") + '/.Bitgroup'
		if not os.path.exists(self.datapath): os.mkdir(self.datapath)

		# Build the Bitmessage RPC URL from the key and password
		port = config.getint('bitmessage', 'port')
		interface = config.get('bitmessage', 'interface')
		username = config.get('bitmessage', 'username')
		password = config.get('bitmessage', 'password')
		self.api = xmlrpclib.ServerProxy("http://"+username+":"+password+"@"+interface+":"+str(port)+"/")

		# Initialise the current user (just using API password for encrypting user data for now)
		self.user = User(config.get('bitmessage', 'addr'), password)

		# Load i18n messages
		self.loadI18n()

		# Initialise groups
		self.loadGroups()

		# Set up a simple HTTP server to handle requests from the interface
		srv = http.server('localhost', config.getint('interface', 'port'))

		return None

	# Update the config file and save it
	def updateConfig(self, section, key, val):
		self.config.set(section, key, val)
		h = open(self.configfile, 'wb')
		self.config.write(h)
		h.close()

	# Load all the groups found in the config file
	def loadGroups(self):
		conf = dict(self.config.items('groups'))
		for passwd in conf:
			prvaddr = conf[passwd]
			print "initialising group: " + prvaddr
			group = Group(prvaddr, passwd)
			self.groups[prvaddr] = group
			print "    group initialised (" + group.name + ")"

	# Read the messages from Bitmessage and store in local app inbox
	def getMessages(self):
		if self.inbox == None:
			messages = json.loads(self.api.getAllInboxMessages())
			self.inbox = []
			for msgID in range(len(messages['inboxMessages'])):
				
				# Get the Bitmessage data for this message
				msg = messages['inboxMessages'][msgID]
				
				# Instantiate a Message or Message sub-class based on it's specified Bitgroup type
				bgmsg = Message.getClass(msg)(msg)

				# If the instance has determined it's not a valid message of it's type, fall back to the Message class
				if bgmsg.invalid: bgmsg = Message(msg)
				
				# Add the instance to the messages
				self.inbox.append(bgmsg)

			print str(len(self.inbox)) + ' messages retrieved.'

	# Return a millisecond timestamp - must match main.js's timestamp
	def timestamp(self):
		return (int(time.strftime('%s'))-1378723000)*1000 + int(datetime.datetime.now().microsecond/1000)

	# Return data about the dynamic state of the application
	def getStateData(self):

		# If the state data is older than one second, rebuild it
		ts = self.timestamp()
		if ts - self.stateAge > 1000:
			self.stateAge = ts

			# Is Bitmessage available?
			try:
				self.state['bm'] = self.api.add(2,3)
				if self.state['bm'] == 5: self.state['bm'] = 'Connected'
				else: self.state['bm'] = 'Error: ' + self.state['bm']
			except:
				self.state['bm'] = 'Not running'

			# If Bitmessage was available add the message list info
			if self.state['bm'] == 'Connected':
				self.getMessages()
				self.state['inbox'] = []
				for msg in self.inbox:
					data = {'from': msg.fromAddr, 'subject': msg.subject}
					cls = str(msg.__class__.__name__)
					if cls != 'Message':
						data['data'] = msg.data
						data['data']['type'] = cls
					self.state['inbox'].append(data)

		return self.state

	# Load the i18n messages
	def loadI18n(self):
		h = open(self.docroot + '/i18n.json', "r")
		self.i18n = json.loads(h.read())
		h.close()

	# Return message from key
	def msg(self, key, s1 = False, s2 = False, s3 = False, s4 = False, s5 = False):
		lang = self.user.lang

		# Get the string in the user's language if defined
		if lang in self.i18n and key in self.i18n[lang]: str = self.i18n[lang][key]

		# Fallback on the en version if not found
		elif key in self.i18n['en']: str = self.i18n['en'][key]

		# Otherwise use the message key in angle brackets
		else: str = '<' + key + '>';

		# Replace variables in the string
		if s1: str = str.replace('$1', s1);
		if s2: str = str.replace('$2', s2);
		if s3: str = str.replace('$3', s3);
		if s4: str = str.replace('$4', s4);
		if s5: str = str.replace('$5', s5);

		return str;

	# Create a new group
	def newGroup(self, name):

		# TODO: Sanitise the name

		# Create a new group instance
		group = Group(self, name)
		
		# If a Bitmessage address was created successfully, create the group's bitmessage addresses and add to the config
		if re.match('BM-', group.addr):
			print "new password created: " + group.passwd
			print "new Bitmessage address created: " + group.addr
			print "new private Bitmessage address created: " + group.prvaddr
			self.groups[group.prvaddr] = group
			data = {'name':name, 'addr':group.addr, 'prvaddr':group.prvaddr}

		# No address was created, return the error (TODO: exceptions not handled during creation)
		else: data = {'err':group.addr}

		return data






