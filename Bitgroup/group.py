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
