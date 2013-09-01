# Class representing the current user
import extensions
from node import *
from bminterface import *

class User(bmAddress,Node):
	def __init__(self):

		# Add extensions that extend the group class to this class
		extensions.add()

		return None

	# return a list of all the groups the user is a member of
	def getGroups():
		return None;
