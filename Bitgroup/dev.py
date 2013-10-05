#!/usr/bin/python2.7
import json

class fakeBitmessage:
	"""
	A fake Bitmessage daemon for testing locally without needing the real thing running
	"""
	messages = {}
	subscriptions = {}

	def __init__(self):

		# TODO: run multiple instances
		
		# TODO: load the messages and subscriptions
		
		pass

	def deliver(self, k, msg):
		if not k in self.messages: self.messages[k] = { 'inboxMessages': {} }
		msgID = len(self.messages[k])
		self.messages[k][msgID] = msg
		# TODO: store this to disk

	def addSubscription(self, addr, label = None):
		k = app.user.addr
		if not k in self.subscriptions: self.subscriptions[k] = []
		self.subscriptions[k].append(addr)
		# TODO: store this to disk

	def sendMessage(self, toAddr, fromAddr, subject, body):
		self.deliver(toAddr, {
			'toAddress': toAddr,
			'fromAddress': fromAddr,
			'subject': subject,
			'message': body
		})

	def sendBroadcast(self, fromAddr, subject, body):
		if fromAddr in self.subscriptions:
			for k in self.subscriptions[fromAddr]:
				self.deliver(k, {
					'fromAddress': fromAddr,
					'subject': subject,
					'message': body
				})

	def getAllInboxMessages(self):
		k = app.user.addr
		if not k in self.messages: self.messages[k] = { 'inboxMessages': {} }
		return json.dumps(self.messages[k])
		
	def createDeterministicAddresses(self, passwd, num):
		addr = { 'addresses': [] }
		for i in range(1, num): addr['addresses'].append('BM-' + hashlib.md5(passwd + str(num)).hexdigest())
		return json.dumps(addr)
		
	def add(self, a, b):
		return a + b
