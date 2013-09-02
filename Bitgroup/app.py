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
	"""The main top-level class for all teh functionality of the Bitgroup application"""

	messages = []
	events = {}
	groups = {}

	def __init__(self):

		# Read the configuration file
		config = ConfigParser.SafeConfigParser();
		config.read(os.path.dirname(__file__) + '/.config')
		self.port = config.get('interface', 'port')
		self.version = '0.0.0'

		# Get location of Bitmessage from config, same location is this if not defined
		try:
			bmsrc = config.get('bitmessage', 'program')
		except:
			bmsrc = os.path.dirname(os.path.dirname(__file__)) + '/PyBitmessage/src'
		if os.path.exists(bmsrc):
			sys.path.append(bmsrc)
		else:
			print "Error: Couldn't find Bitmessage src directory."
			exit

		# Set the location for application data and create the dir if it doesn't exist
		self.datapath = "~/.Bitgroup"
		if not os.path.exists(self.datapath):
			os.mkdir(self.datapath)

		# Build the Bitmessage RPC URL from the key and password
		port = config.getint('bitmessage', 'port')
		interface = config.get('bitmessage', 'interface')
		username = config.get('bitmessage', 'username')
		password = config.get('bitmessage', 'password')
		self.api = xmlrpclib.ServerProxy("http://"+username+":"+password+"@"+interface+":"+str(port)+"/")

		# Initialise the current user
		self.user = user.User(config.get('bitmessage', 'addr'))

		# Initialise groups
		self.groups = self.user.getGroups()

		# Initialise the messages list
		self.getMessages()

		# Set up a simple HTTP server to handle requests from the interface
		srv = http.server('localhost', self.config.port)

		return None

	# Read the messages from Bitmessage abd store in local app list
	def getMessage():
		return []
