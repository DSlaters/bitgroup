from node import *

class User(Node):
	"""
	Class representing the current user
	"""

	def __init__(self, addr, passwd):

		# Set the Bitmessage address for this user
		self.addr = addr

		# User's just have one address, so set the private address to the same as the public
		self.prvaddr = addr

		# Set the user's passpwd for encrypting stored data and messages
		self.passwd = passwd

		# TODO: lang pref
		self.lang = 'en'

		# Get the interface user and password from the app's config
		self.iuser = app.config.get('interface', 'username')
		self.ipass = app.config.get('interface', 'password')

		return None


