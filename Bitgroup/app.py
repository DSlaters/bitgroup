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

class App:
	"""The main top-level class for all teh functionality of the Bitgroup application"""

	name = None
	messages = []
	user = {}
	groups = {}
	maxage = 600000 # Expiry time of queue items in milliseconds
	i18n = {}       # i18n interface messages loaded from interface/i18n.json

	state = {}      # Dynamic application state information
	stateAge = 0    # Last time the dynsmic application state data was updated

	def __init__(self, config):

		self.name = 'Bitgroup'
		self.version = '0.0.0'
		self.docroot = os.path.dirname(__file__) + '/interface'

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
		self.user = User(self, config.get('bitmessage', 'addr'), password)

		# Initialise groups
		self.groups = self.user.getGroups()

		# Initialise the messages list
		#self.getMessages()

		# Set up a simple HTTP server to handle requests from the interface
		srv = http.server(self, 'localhost', config.getint('interface', 'port'))

		return None

	# Read the messages from Bitmessage and store in local app list
	def getMessages(self):
		self.messages = json.loads(self.api.getAllInboxMessages())

	# Return a millisecond timestamp - must match main.js's timestamp
	def timestamp(self):
		return (int(time.strftime('%s'))-1378723000)*1000 + int(datetime.datetime.now().microsecond/1000)

	# Return data about the dynamic state of the application
	def getStateData(self):

		# If the state data is older than one second, rebuild it
		ts = self.timestamp()
		if ts - self.stateAge > 1000:
			
			# Is Bitmessage available?
			try:
				self.state['bm'] = self.api.add(2,3)
				if self.state['bm'] == 5: self.state['bm'] = 'Connected'
				else: self.state['bm'] = 'Error: ' + self.state['bm']
			except:
				self.state['bm'] = 'Not running'

			# Do we have net access?
			
			self.stateAge = ts

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
		elif key in self.i18n.en: str = self.i18n['en'][key]

		# Otherwise use the message key in angle brackets
		else: str = '<' + key + '>';

		# Replace variables in the string
		if s1: str = str.replace('$1', s1);
		if s2: str = str.replace('$2', s2);
		if s3: str = str.replace('$3', s3);
		if s4: str = str.replace('$4', s4);
		if s5: str = str.replace('$5', s5);

		return str;

