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
			found = False
			for g in app.groups:
				if g.prvaddr == group: found = g
			if found: self = found
		return object.__new__(self, group, passwd)

	"""
	Initialise the new group instance
	"""
	def __init__(self, group, passwd = None):

		# If instantiating by address,
		if re.match('BM-', group):

			# If we've provided a passwd, then we're initialising the instance
			if passwd:
				self.prvaddr = group
				self.passwd = passwd
				self.addr = self.get('settings.addr')
				self.name = self.get('settings.name')

		# Instantiating by name, create a new group
		else:
			self.name = group

			# Make a new random password - encrypting with openssl in case uuid's not very random
			self.passwd = self.encrypt(str(uuid.uuid4()),str(uuid.uuid4())).encode('base64').strip().lower()
		
			# Now create two address from the passphrase
			addrs = json.loads(app.api.createDeterministicAddresses(self.passwd, 2))
			self.addr = addrs['addresses'][0]
			self.prvaddr = addrs['addresses'][1];

			# Update the config file with the private address and password (all thats needed to be a member)
			app.updateConfig('groups', self.passwd, self.prvaddr)

			# Initialise the group's data to the template
			global template
			for k in template: self.set(k, template[k])
			self.set('settings.name', self.name)
			self.set('settings.addr', self.addr)

		return None

"""
Data structure of a newly created group
"""
template = {
	'settings.name': '',
	'settings.addr': '',
	'settings.extensions': [],
	'settings.tags': [],
	'settings.skin': 'default',

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

