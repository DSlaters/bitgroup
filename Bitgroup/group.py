from node import *
from bminterface import *

class Group(BitmessageAddress, Node):
	"""This is the class that messages from the Bitmessage inbox are returned as if they're for our app"""

	def __init__(self, app, addr, passwd):
		self.app = app

		# Set the Bitmessage address for this user
		self.addr = addr

		# Set the group's passpwd for encrypting stored data and messages
		self.passwd = passwd

		# TODO: get the group's private address from the properties

		return None

# Data structure of a newly created group
template = {
	'Contact': {
		'type': 'Node',
		'views': ['Properties'],
		'template': True,
		'title': 'Nickname',
		'Nickname': '',
		'First name': '',
		'Surname': '',
		'Email': '',
		'Bitmessage': '',
		'Phone': ''
	},
	'Page': {
		'type': 'Node',
		'views': ['Edit','Properties','Attachments'],
		'template': True,
		'title': 'Name',
		'Name': ''
	},
	'Blog': {
		'type': 'Node',
		'views': ['Post','Properties'],
		'template': True,
		'title': 'Name',
		'Name': ''
	},
	'settings': {
		'extensions': [],
		'tags': [],
		'skin': 'default',
	}
}
