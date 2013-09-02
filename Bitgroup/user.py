import extensions
from node import *
from bminterface import *

class User(BitmessageAddress, Node):
	"""Class representing the current user"""

	def __init__(self, addr, passwd):

		# Set the Bitmessage address for this user
		self.addr = addr

		# Set the user's passpwd for encrypting stored data and messages
		self.passwd = passwd

		return None

	# return a list of all the groups the user is a member of
	def getGroups():
		return None;
