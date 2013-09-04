import os
import sys
import re
import http
import xmlrpclib
import json
from user import *
from group import *

class App:
	"""The main top-level class for all teh functionality of the Bitgroup application"""

	name = None
	messages = []
	events = {}
	groups = {}

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
		self.user = User(config.get('bitmessage', 'addr'), password)

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
