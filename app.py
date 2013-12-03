import __builtin__
import os, sys, re, threading
import uuid, urllib, xmlrpclib, json
import time, datetime

# Bitmessage modules
import hashlib
import pyelliptic
import highlevelcrypto
from pyelliptic.openssl import OpenSSL
from bitmessagemain import pointMult

# Bitgroup modules
from dev import *
from server import *
from user import *
from group import *
from message import *

class App:
	"""
	The main top-level class for all teh functionality of the Bitgroup application
	"""

	name         = 'Bitgroup'
	version      = '0.0.0'
	title        = name + "-" + version
	peer         = None
	ip           = None

	docroot      = os.path.dirname(__file__) + '/interface'
	datapath     = os.getenv("HOME") + '/.Bitgroup'
	config       = None
	configfile   = None
	api          = None
	dev          = False
	devnum       = 0

	server       = None    # Singleton instance of the server for communicating with interface clients and peers
	user         = None    # Singleton instance of the user
	groups       = {}      # Instances of groups the user belongs to
	maxage       = 600000  # Expiry time of queue items in milliseconds
	i18n         = {}      # i18n interface messages loaded from interface/i18n.json
	stateAge     = 0       # Last time the dynamic application state data was updated
	lastInterval = 0       # Last time the interval timer was called

	"""
	Initialise the application
	"""
	def __init__(self, config, configfile):
		self.config = config
		self.configfile = configfile

		# Make the app a "superglobal"
		__builtin__.app = self

		# If running in dev mode, define which instance we are and how many there are from the command line args
		if len(sys.argv) > 1 and sys.argv[1] == 'dev':
			self.devnum = int(sys.argv[2]) if len(sys.argv) > 2 else 3
			if len(sys.argv) < 4: self.dev = 1
			elif len(sys.argv) == 4: self.dev = int(sys.argv[3])

		# Give the local instance a unique session ID for real-time communication with peers
		self.peer = self.guid()

		# Build the Bitmessage RPC URL from the key and password
		port = config.getint('bitmessage', 'port')
		interface = config.get('bitmessage', 'interface')
		username = config.get('bitmessage', 'username')
		password = config.get('bitmessage', 'password')

		# Initialise the current user
		self.user = User()
		self.log("User \"" + self.user.nickname + "\" (" + self.user.addr + ") initialised")

		# If in dev mode, use the fake Bitmessage class, otherwise set up the API connection to the real thing
		if self.dev: self.api = fakeBitmessage()
		else: self.api = xmlrpclib.ServerProxy("http://"+username+":"+password+"@"+interface+":"+str(port)+"/")

		# Create the user data dir if it doesn't exist
		if not os.path.exists(app.datapath): os.mkdir(app.datapath)

		# Load i18n messages
		self.loadI18n()

		# Initialise groups
		self.loadGroups()

		# Set up a simple HTTP server to handle requests from any interface on our port
		self.server = Server('127.0.0.1', self.config.getint('interface', 'port'))

		# Call the regular interval timer
		hw_thread = threading.Thread(target = self.interval)
		hw_thread.daemon = True
		hw_thread.start()

		return None

	"""
	Regular interval timer
	"""
	def interval(self):
		while(True):
			self.getStateData()
			now = self.timestamp()
			ts = self.lastInterval
			self.lastInterval = now

			"""
			Test closing from local end to see if handle_close is called
			for i in app.server.clients:
				if app.server.clients[i].role is INTERFACE:
					app.log('Closing ' + i)
					app.server.clients[i].close()
			"""

			# If we have no IP address, try and obtain it and if successful, broardcast our presence to our groups
			if self.ip is None:
				self.ip = self.getExternalIP()
				if self.ip:
					for g in app.groups:
						Presence(app.groups[g]).send()
			
			# TODO: Send outgoing queued changes messages every 10 minutes (or 10 seconds if in dev mode)
			if app.dev or now - ts > 595000:
				for g in app.groups:
					app.groups[g].sendChanges()

			time.sleep(10)

	"""
	Update the config file and save it
	"""
	def updateConfig(self, section, key, val):
		self.config.set(section, key, val)
		h = open(self.configfile, 'wb')
		self.config.write(h)
		h.close()
		app.log(key + ' = ' + val)

	"""
	Load all the groups found in the config file
	"""
	def loadGroups(self):
		conf = dict(self.config.items('groups'))
		for passwd in conf:
			prvaddr = conf[passwd]
			self.log("initialising group: " + prvaddr)
			group = Group(prvaddr, passwd)
			if group.name:
				self.groups[prvaddr] = group
				self.log("    \"" + group.name + "\" initialised successfully")
			else: self.log("    initialisation failed")
				

	"""
	Return a millisecond timestamp - must match main.js's timestamp
	"""
	def timestamp(self):
		return (int(time.strftime('%s'))-1378723000)*1000 + int(datetime.datetime.now().microsecond/1000)

	"""
	Update the dynamic application state data
	"""
	def getStateData(self):

		# If the state data is older than one second, rebuild it
		ts = self.timestamp()
		if ts - self.stateAge > 1000:
			self.stateAge = ts

			# Is Bitmessage available?
			try:
				state = self.api.add(2,3)
				if state == 5: state = CONNECTED
				else: state = ERROR
			except:
				state = NOTCONNECTED
			self.user.setData(STATE, 'bm', state)

			# If Bitmessage was available add any new messages
			# - these are in app.inbox, not app.state, but are sent in Server.pushState
			if state is CONNECTED:
				for msg in Message.getMessages():
					if self.user.getData('inbox.' + msg.uid) is None:
						data = {
							'type':    msg.__class__.__name__,
							'group':   None,
							'from':    msg.fromAddr,
							'subject': msg.subject,
							'sent':    False
						}
						if data['type'] != 'Message':
							data['data'] = msg.data
							data['group'] = msg.group.prvaddr
							data['subject'] = ''
						self.user.setData(STATE, 'inbox.' + msg.uid, data)

	"""
	Return whether or not Bitmessage is connected
	"""
	def bmConnected(self):
		return app.user.getData('bm') is CONNECTED

	"""
	Load the i18n messages
	"""
	def loadI18n(self):
		h = open(self.docroot + '/i18n.json', "r")
		self.i18n = json.loads(h.read())
		h.close()

	"""
	Return message from key
	"""
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

	"""
	Create a new group
	"""
	def newGroup(self, name):

		# TODO: Sanitise the name

		# Create a new group instance
		group = Group(name)
		
		# If a Bitmessage address was created successfully, create the group's bitmessage addresses and add to the config
		if re.match('BM-', group.addr):
			self.log("new password created: " + group.passwd)
			self.log("new Bitmessage address created: " + group.addr)
			self.log("new private Bitmessage address created: " + group.prvaddr)
			self.groups[group.prvaddr] = group
			data = {'name':name, 'addr':group.addr, 'prvaddr':group.prvaddr}

		# No address was created, return the error (TODO: exceptions not handled during creation)
		else: data = {'err': group.addr}

		return data

	"""
	Send a group invitation to a Bitmessage address
	TODO: need proper reporting on sent status
	"""
	def SendInvitation(self, group, addr):
		msg = Invitation(group, addr)
		if msg:
			msg.send()
			return {'success': True}
		return {'err': 'Invitation message could not be created'}

	"""
	Encrypt the passed data using a password
	"""
	def encrypt(self, data, passwd):
		privKey = hashlib.sha512(passwd).digest()[:32]
		pubKey = pointMult(privKey)
		return highlevelcrypto.encrypt(data, pubKey.encode('hex'))

	"""
	Decrypt the passed encrypted data
	"""
	def decrypt(self, data, passwd):
		privKey = hashlib.sha512(passwd).digest()[:32]
		return highlevelcrypto.decrypt(data, privKey.encode('hex'))

	"""
	Get the external IP address of this host
	- this should only be a backup to use if no peers are available to ask
	"""
	def getExternalIP(self):
		if self.dev: return 'localhost'
		try: html = urllib.urlopen("http://checkip.dyndns.org/").read()
		except: return None
		match = re.search(r'(\d+\.\d+.\d+.\d+)', html)
		if match:
			self.log("External IP address of local host is " + match.group(1))
			return match.group(1)
		self.log("Could not obtain external IP address")
		return None

	"""
	Create a general purpose GUID
	"""
	def guid(self):
		return self.encrypt(str(uuid.uuid4()),str(uuid.uuid4())).encode('base64')[:8]

	"""
	Custom logging method so we can specify how to log output from dev main and sub-instances or non-dev
	"""
	def log(self, msg):
		if self.dev: msg = '[' + app.user.nickname + ']: ' + msg
		print msg

	"""
	Convert a constant value back to its defined identifier - used in logging only
	"""
	def cname(self, val):
		for k in constants:
			if constants[k] == val: return k
		return 'UNDEFINED'
