from node import *

class User(Node):
	"""
	Class representing the current user
	"""

	# Name used to refer to the user if instanitiating from a group (nickname if supplied, full name if none given)
	name = None 

	# User's language preference
	lang = None

	# Data obtained from config file or group member info
	nickname  = None
	firstname = None
	surname   = None
	email     = None
	website   = None

	def __init__(self, addr = None, group = None):

		# If no address given, then instantiate local user from config
		if addr is None:
			self.addr = app.config.get('user', 'bmaddr')
			self.addr = app.config.get('user', 'nickname')
			self.addr = app.config.get('user', 'firstname')
			self.addr = app.config.get('user', 'surname')
			self.addr = app.config.get('user', 'email')
			self.addr = app.config.get('user', 'website')

			# User's just have one address, so set the private address to the same as the public
			self.prvaddr = addr

			# Use the user's API password as their private key for now
			self.passwd = app.config.get('bitmessage', 'password')

			# Get the interface user and password from the app's config
			self.iuser = app.config.get('interface', 'username')
			self.ipass = app.config.get('interface', 'password')

		# Otherwise an address and a group should have been provided
		else:
			user = None
			for u in group.getData('members'):
				if u.addr == addr: user = u
			if user:
				self.name = u.Nickname
				if not self.name: self.name = u.Firstname + ' ' + u.Surname

		return None

	"""
	Return a record of the user data for use in Presence messages and in group member information
	"""
	def info(self):
		return {
			'bmAddr':    self.addr,
			'Nickname':  self.nickname,
			'Firstname': self.firstname,
			'Surname':   self.surname,
			'Email':     self.email,
			'Website':   self.website
		}
