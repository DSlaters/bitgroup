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
	groups = {}
	maxage = 600000 # Expiry time of queue items in milliseconds

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
