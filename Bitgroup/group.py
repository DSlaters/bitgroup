import uuid
import re
from node import *
from bminterface import *

class Group(BitmessageAddress, Node):
	"""This is the class that messages from the Bitmessage inbox are returned as if they're for our app"""

	name = None     # The textual name for the group (can be changed any time)
	addr = None     # The public Bitmessage address for the group (anyone can subscribe to this)
	prvaddr = None  # The private Bitmessage address for the group (only members can read info from this address)

	# Instantiate a group instance
	def __init__(self, app, group, passwd = None):
		self.app = app

		# If instantiating by address, it's an existing group that needs to be initialised
		if re.match('BM-', group):
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

# Data structure of a newly created group
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

