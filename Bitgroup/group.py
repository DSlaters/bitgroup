import extensions
from node import *
from bminterface import *

class Group(BitmessageAddress, Node):
	"""This is the class that messages from the Bitmessage inbox are returned as if they're for our app"""

	def __init__(self):

		# Add extensions that extend the group class to this class
		extensions.add()

		return None
