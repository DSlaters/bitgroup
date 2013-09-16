from node import *
from bminterface import *
from group import Group

class User(BitmessageAddress, Node):
	"""Class representing the current user"""

	def __init__(self, app, addr, passwd):
		self.app = app

		# Set the Bitmessage address for this user
		self.addr = addr

		# Set the user's passpwd for encrypting stored data and messages
		self.passwd = passwd

		# TODO: lang pref
		self.lang = 'en'

		return None

	# TODO: Return a list of all the groups the user is a member of
	def getGroups(self):
		return {'Organic Design': Group(self.app, 'BM-blablablabla','foobas!@#$')};
