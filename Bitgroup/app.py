import __builtin__
import os, sys, re, threading
import uuid, http, urllib, xmlrpclib, json
import time, datetime

# Bitmessage modules
import hashlib
import pyelliptic
import highlevelcrypto
from pyelliptic.openssl import OpenSSL
from bitmessagemain import pointMult

# Bitgroup modules
from user import *
from group import *
from message import *

class App:
	"""
	The main top-level class for all teh functionality of the Bitgroup application
	"""

	name = 'Bitgroup'
	version = '0.0.0'
	title = name + "-" + version
	peer = None
	ip = None

	docroot = os.path.dirname(__file__) + '/interface'
	datapath = os.getenv("HOME") + '/.Bitgroup'
	config = None
	configfile = None
	api = None

	server = None
	inbox = None
	user = {}
	groups = []
	maxage = 600000   # Expiry time of queue items in milliseconds
	i18n = {}         # i18n interface messages loaded from interface/i18n.json
	state = {}        # Dynamic application state information
	stateAge = 0      # Last time the dynamic application state data was updated
	lastInterval = 0  # Last time the interval timer was called

	"""
	Initialise the application
	"""
	def __init__(self, config, configfile):
		self.config = config
		self.configfile = configfile

		# Make the app a "superglobal"
		__builtin__.app = self

		# Create the dir if it doesn't exist
		if not os.path.exists(self.datapath): os.mkdir(self.datapath)

		# Give the local instance a unique session ID for real-time communication with peers
		self.peerID = self.encrypt(str(uuid.uuid4()),str(uuid.uuid4())).encode('base64')[:8]

		# Build the Bitmessage RPC URL from the key and password
		port = config.getint('bitmessage', 'port')
		interface = config.get('bitmessage', 'interface')
		username = config.get('bitmessage', 'username')
		password = config.get('bitmessage', 'password')
		self.api = xmlrpclib.ServerProxy("http://"+username+":"+password+"@"+interface+":"+str(port)+"/")

		# Initialise the current user
		self.user = User()

		# Load i18n messages
		self.loadI18n()

		# Initialise groups
		self.loadGroups()

		# Set up a simple HTTP server to handle requests from any interface on our port
		self.server = http.Server('127.0.0.1', config.getint('interface', 'port'))

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
			now = self.timestamp()
			ts = self.lastInterval
			self.lastInterval = now

			# If we have no IP address, try and obtain it and if successful, broardcast our presence to our groups
			if self.ip is None:
				self.ip = self.getExternalIP()
				if self.ip:
					for g in app.groups:
						Presence(g).send()

			# Check for new messages every 10 seconds
			Message.getMessages(self.inbox)
			
			# TODO: Send outgoing queued changes messages every 10 minutes
			if now - ts > 595000:
				for g in app.groups:
					g.sendChanges()

			time.sleep(10)

	"""
	Update the config file and save it
	"""
	def updateConfig(self, section, key, val):
		self.config.set(section, key, val)
		h = open(self.configfile, 'wb')
		self.config.write(h)
		h.close()

	"""
	Load all the groups found in the config file
	"""
	def loadGroups(self):
		conf = dict(self.config.items('groups'))
		for passwd in conf:
			prvaddr = conf[passwd]
			print "initialising group: " + prvaddr
			group = Group(prvaddr, passwd)
			self.groups.append(group)
			print "    group initialised (" + group.name + ")"

	"""
	Return a millisecond timestamp - must match main.js's timestamp
	"""
	def timestamp(self):
		return (int(time.strftime('%s'))-1378723000)*1000 + int(datetime.datetime.now().microsecond/1000)

	"""
	Return data about the dynamic state of the application
	"""
	def getStateData(self):

		# If the state data is older than one second, rebuild it
		ts = self.timestamp()
		if ts - self.stateAge > 1000:
			self.stateAge = ts

			# Is Bitmessage available?
			try:
				self.state['bm'] = self.api.add(2,3)
				if self.state['bm'] == 5: self.state['bm'] = CONNECTED
				else:
					self.state['bm_err'] = self.state['bm']
					self.state['bm'] = ERROR
			except:
				self.state['bm'] = NOTCONNECTED

			# If Bitmessage was available add the message list info
			if self.state['bm'] is CONNECTED:
				self.state['inbox'] = []
				for msg in self.inbox:
					data = {'from': msg.fromAddr, 'subject': msg.subject}
					cls = str(msg.__class__.__name__)
					if cls != 'Message':
						data['data'] = msg.data
						data['data']['type'] = cls
					self.state['inbox'].append(data)

		return self.state

	"""
	Return whether or not Bitmessage is connected
	"""
	def bmConnected(self):
		return 'bm' in app.state and app.state['bm'] is CONNECTED

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
		html = urllib.urlopen("http://checkip.dyndns.org/").read()
		match = re.search(r'(\d+\.\d+.\d+.\d+)', html)
		if match:
			print "External IP address of local host is " + match.group(1)
			return match.group(1)
		print "Could not obtain external IP address"
		return None
