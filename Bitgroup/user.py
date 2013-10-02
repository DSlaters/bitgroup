from node import *

class User(Node):
	"""
	Class representing the current user
	"""

	# Name used to refer to the user if instanitiating from a group (nickname if supplied, full name if none given)
	name = None 

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

		# If the parameter is a group, instantiate a user object from the group members
		if param.__class__.__name__ == 'Group':
			user = None
			for u in param.getData('members'):
				if u.addr == addr: user = u
			if user:
				self.name = u.Nickname
				if not self.name: self.name = u.Firstname + ' ' + u.Surname

		# Otherwise the parameter is assumed to be a password for a new local user instance
		else:

			# Set the user's passpwd for encrypting stored data and messages
			self.passwd = passwd

			# TODO: lang pref
			self.lang = 'en'

			# Get the interface user and password from the app's config
			self.iuser = app.config.get('interface', 'username')
			self.ipass = app.config.get('interface', 'password')

		return None

	"""
	Return a record of the user data for use in Presence messages and in group member information
	"""
	def info():
		return {
			'bmAddr':    self.addr,
			'Nickname':  self.nickname,
			'Firstname': self.firstname,
			'Surname':   self.surname,
			'Email':     self.email,
			'Website':   self.website
		}
