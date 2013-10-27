import os, hashlib
from node import *

class User(Node):
	"""
	Class representing the current user
	"""

	# Name used to refer to the user if instanitiating from a group (nickname if supplied, full name if none given)
	name = None 
	
	# To distinguish between users and groups
	isUser = True

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

			# If in dev mode, add a number index number to the user name and use a random BM address
			if app.dev:
				self.nickname = app.config.get('user', 'nickname')
				if app.dev > 1: self.nickname += str(app.dev)
				self.addr = 'BM-' + hashlib.md5(self.nickname).hexdigest()

			else:
				self.addr      = app.config.get('user', 'bmaddr')
				self.nickname  = app.config.get('user', 'nickname')
				self.firstname = app.config.get('user', 'firstname')
				self.surname   = app.config.get('user', 'surname')
				self.email     = app.config.get('user', 'email')
				self.website   = app.config.get('user', 'website')

			# User's just have one address, so set the private address to the same as the public
			self.prvaddr = self.addr

			# Name property is needed
			self.name = self.nickname if self.nickname else self.firstname + ' ' + self.surname

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
	Override this to ensure that user's data is never sent to peers
	"""
	def sendChanges(self):
		app.log("ERROR: Attempt to call sendChanges() for app.user")

	"""
	Return a record of the user data for use in Presence messages and in group member information
	"""
	def info(self):
		return {self.addr: {
			'Nickname':  self.nickname,
			'Firstname': self.firstname,
			'Surname':   self.surname,
			'Email':     self.email,
			'Website':   self.website
		}}
