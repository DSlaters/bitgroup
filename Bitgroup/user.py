import extensions
from node import *
from bminterface import *

class User(BitmessageAddress, Node):
	"""Class representing the current user"""

	def __init__(self, addr):

		# Set the Bitmessage address for this user
		self.addr = addr

		# Add extensions that extend the group class to this class
		extensions.add(self)

		return None

	# return a list of all the groups the user is a member of
	def getGroups():
		return None;
