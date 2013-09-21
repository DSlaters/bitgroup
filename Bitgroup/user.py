from node import *

class User(Node):
	"""Class representing the current user"""

	def __init__(self, app, addr, passwd):
		self.app = app

		# Set the Bitmessage address for this user
		self.addr = addr

		# User's just have one address, so set the private address to the same as the public
		self.prvaddr = addr

		# Set the user's passpwd for encrypting stored data and messages
		self.passwd = passwd

		# TODO: lang pref
		self.lang = 'en'

		return None


