import uuid
import re
import server
from node import *

class Group(Node, object):
	"""This is the class that messages from the Bitmessage inbox are returned as if they're for our app"""

	name = None     # The textual name for the group (can be changed any time)
	isUser = False  # To distinguish between users and groups
	addr = None     # The public Bitmessage address for the group (anyone can subscribe to this)
	prvaddr = None  # The private Bitmessage address for the group (only members can read info from this address)
	server = None   # The current server-peer for the group
	peers = {}      # All the online members in the group (note that we may not be connected with them since the peers form a client-server topology)

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
			self.setData(DATA, 'settings.name', self.name)
			self.setData(DATA, 'settings.addr', self.addr)

			# Add self as the only member
			info = app.user.info()
			addr = info.keys()[0]
			self.setData(DATA, 'members.' + addr, info[addr])

		return None

	"""
	TODO: Determine and set which peer (online member) in the group is the server
	"""
	def determineServer(self):
		self.server = sorted(self.peers.keys())[0]

	"""
	Ensure that the connections amongst the group's peers form a client-server topology
	"""
	def updateConnections(self):

		# If we're the server, we don't do anything since the peers will all connect with us
		if self.server == app.peer:
			pass

		# If we're not the server, make sure we have no connections to peers except for with the server peer
		else:
			clients = app.server.clients

			# Close any non-server peer connections (closing here does not trigger handle_close, so the peers won't be deleted)
			d = []
			for k in clients.keys():
				client = clients[k]
				if client.role is PEER and client.group is self and k != gsrv:
					client.close()
					d.append(k)
			for k in d: del clients[k]

			# Make sure we have a connection to the server
			if not self.server in clients.keys(): self.peerConnect(self.server)

	"""
	Add a new peer and establish a connection with it - data is the format sent by a Presence message
	"""
	def peerAdd(self, data):
		peer = data['peer']

		# Add an entry in the group's peer array for the new peer
		self.peers[peer] = data

		# Since peers have changed, we need to know who's the server now
		self.determineServer()

		# If we are the group server,
		if self.server == app.peer:

			# Connect to the new peer
			self.peerConnect(peer)

			# Respond to the newly connected peer with a Welcome message
			info = { PEER: self.peers() }
			changes = self.changes(data['last'])
			if len(changes) > 0: info[CHANGES] = changes
			conn.sendMessage(WELCOME, info)
			
			# If this is a new member (not in member info), broadcast a message about it to the group (not just the peers)
			nick = data['user'][data['user'].keys()[0]]['Nickname']
			Post(self, app.msg('newmember-subject', nick), app.msg('newmember-body', nick)).send()		

		# Ensure we're connected in accord with the client-server topology since the server may have changed
		self.updateConnections()

	"""
	Delete a peer from the peers list and close any active connection to it
	"""
	def peerDel(self, peer, close = True):
		if not peer in self.peers:
			app.log("peerDel called for peer \"" + peer + "\" in group \"" + self.name + "\" but that peer is not in the peers array")
			return

		# CLose any active connection to the peer
		if close and peer in app.server.clients:
			app.server.clients[peer].close()
			del app.server.clients[peer]

		# Remove the peer from the group's peer array
		app.log("Removing peer \"" + peer + "\" from \"" + group.name + "\" group's peers array")
		del self.peers[peer]

		# If we're the server, tell the other peers that this peer has gone offline
		# - we send a standard PEER structure with just the removed peer ID for key and None for value indicating it should be removed
		if self.server == app.peer: app.server.groupBroadcast(self, STATUS, {PEER: {peer: None} })

		# Determine who's the server now
		self.determineServer()

		# Ensure we're connected in accord with the client-server topology since the server may have changed
		self.updateConnections()

	"""
	Establish a connection with a peer in the peers list
	"""
	def peerConnect(self, peer):

		# Create a socket and connect to the new peer
		sock = app.server.connect((self.peers[peer]['ip'], self.peers[peer]['port']))
		conn = server.Connection(app.server, sock)

		# Add the peer's info to the server's active clients list
		app.server.clients[peer] = conn
		conn.role = PEER
		conn.group = self



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

