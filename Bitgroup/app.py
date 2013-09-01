import os
import sys
import re
import ConfigParser
import http
import xmlrpclib
import json
from user import *
from group import *

class App:
	'The main top-level class for all teh functionality of the Bitgroup application'

	config = ()
	messages = ()
	events = ()
	user = ()
	groups = ()
	
	def __init__(self):

		# Read the configuration file
		config = ConfigParser.SafeConfigParser();
		config.read(os.path.dirname(__file__) + '/.config')
		self.config.port = config.get('interface', 'port')
		self.config.version = '0.0.0'
		self.config.api.port = config.getint('bitmessage', 'port')
		self.config.api.interface = config.get('bitmessage', 'interface')
		self.config.api.username = config.get('bitmessage', 'username')
		self.config.api.password = config.get('bitmessage', 'password')

		# Build the Bitmessage RPC URL from the key and password
		self.rpc_url = "http://"+self.config.api.username+":"+self.config.api.password+"@"+self.config.api.interface+":"+str(self.config.api.port)+"/"

		# Initialise the current user
		self.user = user.User()

		# Initialise groups
		self.groups = self.user.getGroups()

		# Initialise the messages list
		self.getMessages()

		# Set up a simple HTTP server to handle requests from the interface
		srv = http.server('localhost', self.config.port)

		return None

	# Retrieve the messages from the Bitmessage inbox returning ours as the appropriate class
	def getMessages:
		api = xmlrpclib.ServerProxy(self.config.rpc_url)
		self.messages = json.loads(api.getAllInboxMessages())


