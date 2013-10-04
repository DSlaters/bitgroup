#!/usr/bin/python2.7

# TODO: launch more instance of the program if dev set

class fakeBitmessage:
	"""
	A fake Bitmessage daemon for testing locally without needing the real thing running
	"""
	messages = {}

	def sendMessage(self, toAddr, fromAddr, subject, body):
		pass

	def sendBroadcast(self, fromAddr, subject, body):
		pass

	def getAllInboxMessages(self):
		pass
