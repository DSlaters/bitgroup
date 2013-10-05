import uuid
import re
from node import *

class Group(Node, object):
	"""This is the class that messages from the Bitmessage inbox are returned as if they're for our app"""

	name = None     # The textual name for the group (can be changed any time)
	addr = None     # The public Bitmessage address for the group (anyone can subscribe to this)
	prvaddr = None  # The private Bitmessage address for the group (only members can read info from this address)
	server = False  # Whether or not we are the server for this group

	"""
	Instantiate a new group instance, return the existing instance if the passed group already has one
	"""
	def __new__(self, group, passwd = None):
		if re.match('BM-', group) and passwd == None:
			for g in app.groups:
				if g.prvaddr == group: return g
		return object.__new__(self, group, passwd)

	"""
	Initialise the new group instance
	"""
	def __init__(self, param, passwd = None):

		# If instantiating by address,
		if re.match('BM-', param):

			# If we've provided a passwd, then we're initialising the instance
			if passwd:
				self.prvaddr = param
				self.passwd = passwd
				self.addr = self.getData('settings.addr')
				self.name = self.getData('settings.name')

		# Instantiating by name, create a new group
		else:
			if not passwd:
				app.log("Invalid Group instantiation, \"" + param + "\" and no passwd")
				return None
			if not app.bmConnected():
				app.log("Not creating group \"" + param + "\", Bitmessage not connected")
				return None

			self.name = param

			# Make a new random password - encrypting with openssl in case uuid's not very random
			self.passwd = app.encrypt(str(uuid.uuid4()),str(uuid.uuid4())).encode('base64').strip().lower()
		
			# Now create two address from the passphrase
			addrs = json.loads(app.api.createDeterministicAddresses(self.passwd, 2))
			self.addr = addrs['addresses'][0]
			self.prvaddr = addrs['addresses'][1];

			# Subscribe to both of the addresses
			app.api.subscribe(self.addr, app.msg('private-addr', self.name))
			app.api.subscribe(self.addr, app.msg('public-addr', self.name))

			# Update the config file with the private address and password (all thats needed to be a member)
			app.updateConfig('groups', self.passwd, self.prvaddr)

			# Initialise the group's data from the template
			global template
			for k in template: self.setData(k, template[k])
			self.setData('settings.name', self.name)
			self.setData('settings.addr', self.addr)

			# Add self as the only member
			self.setData(settings.members, [app.user.info()])

		return None

	"""
	Determine and set which peer (online member) in the group is the server
	"""
	def determineServer(self):

		# TODO: who's server? - for now just sort by bm addresses and pick the first
		gsrv = app.peer == self.peers().sort()[0]

		# if not server now, but was before, close all peer sockets for this group
		if self.server and not gsrv:
			clients = app.server.clients
			d = []
			for k in clients.keys():
				client = clients[k]
				if CLIENTSOCK in client and client[GROUP] is g:
					client[CLIENTSOCK].close()
					d.append(k)
			for k in d: del clients[k]

		g.server = gsrv
		return gsrv

	"""
	Return the ID's for all the current peers from the server's active clients list
	"""
	def peers(self):
		clients = app.server.clients
		peers = []
		for k in clients.keys():
			client = clients[k]
			if CLIENTSOCK in client and client[GROUP] is self:
				peers.append(k)
		return peers

	"""
	Add a new peer and establish a connection with it - data is the format sent by a Presence message
	"""
	def addPeer(self, data):

		# Add the peer's info to the server's active clients list
		app.server.clients[peer] = {
			CLIENTSOCK: sock,
			GROUP: self.group
		}

		# Since peers have changed, we need to know who's the server now
		self.determineServer()

		# If we are the group server,
		if self.group.server:
			
			# Open a socket to the new peer
			sock = app.server.connect((data['ip'], data['port']))

			# Send data since peer's last data and the current peer info
			data = {PEERS: group.peers()}
			changes = group.changes(self.data['last'])
			if len(changes) > 0: data[CHANGES] = changes
			sock.push(json.dumps(data))
			
			# TODO: If this is a new member (not in member info), broadcast a message about it to the group
			Post(self.group, subject, body).send()		

	"""
	Delete a peer from the active peers list
	"""
	def delPeer(self, peer, close = True):
		if close: app.server.clients[peer][CLIENTSOCK].close()
		del app.server.clients[peer]
		self.determineServer()


"""
Data structure of a newly created group
"""
template = {
	'settings.name': '',
	'settings.addr': '',
	'settings.extensions': [],
	'settings.tags': [],
	'settings.skin': 'default',

	'members': [],

	'Contact.type': 'Node',
	'Contact.views': ['Properties'],
	'Contact.template': True,
	'Contact.title': 'Nickname',
	'Contact.Nickname': '',
	'Contact.First name': '',
	'Contact.Surname': '',
	'Contact.Email': '',
	'Contact.Bitmessage': '',
	'Contact.Phone': '',

	'Page.type': 'Node',
	'Page.views': ['Edit','Properties','Attachments'],
	'Page.template': True,
	'Page.title': 'Name',
	'Page.Name': '',

	'Blog.type': 'Node',
	'Blog.views': ['Post','Properties'],
	'Blog.template': True,
	'Blog.title': 'Name',
	'Blog.Name': '',
}

