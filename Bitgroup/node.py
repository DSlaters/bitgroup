import os
import json
import hashlib
import pyelliptic
import highlevelcrypto
from pyelliptic.openssl import OpenSSL
from bitmessagemain import pointMult

class Node:
	"""
	User and Group classes inherit this functionality so they can have a persistent properties structure.
	The data is stored encrypted using the encryption functions directly from the PyBitmessage source.
	"""

	data = None    # cache of this node's data
	passwd = None  # used to ecrypt data and messages for this user or group
	queue = []

	# Get a property in this nodes data structure
	def get(self, key):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

		# Split key path and walk data path to get value
		val = self.data
		for i in key.split('.'):
			if type(val) == dict and i in val:
				val = val[i]
			else:
				return None

		return val

	# Set a property in this nodes data structure
	def set(self, key, val):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

		# Split key path and walk data path to set value, create non-existent items
		j = self.data
		path = key.split('.')
		leaf = path.pop()
		for i in path:
			if type(j) == dict and i in j:
				j = j[i]
			else:
				if not type(j) == dict:
					print "Failed to set " + key + " as a value already exists at path element '" + i + "'"
					return None
				j[i] = {}
				j = j[i]

		# Anything changed?
		oldval = j[leaf]
		j[leaf] = val
		change = json.dumps(oldval) != json.dumps(val)

		# Save the updated data if changed
		if changed: self.save()

		# Return state of change
		return change

	# TODO
	def remove(self):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

	# Get the filesystem location of this node's data
	def path(self):
		return self.app.datapath + '/' + self.addr + '.json'

	# Load this node's data into the local cache
	def load(self):
		f = self.path()
		if os.path.exists(f):
			h = open(f, "rb")
			self.data = self.decrypt(json.loads(h.read()), self.passwd)
			h.close()
		else:
			self.data = {}

	# Save the local cache to the data file
	# TODO: data changes should queue and save periodically, not on every property change
	def save(self):
		f = self.path()
		h = open(f, "wb+")
		h.write(self.encrypt(json.dumps(self.data), self.passwd));
		h.close()

	# Return the data as JSON for the interface
	def json(self):
		if self.data == None: self.load()
		return json.dumps(self.data)

	# Encrypt the passed data using a password
	def encrypt(self, data, passwd):
		return data # no encryption while debgging
		privKey = hashlib.sha512(passwd).digest()[:32]
		pubKey = pointMult(privKey)
		return highlevelcrypto.encrypt(data, pubKey.encode('hex'))

	# Decrypt the passed encrypted data
	def decrypt(self, data, passwd):
		return data # no encryption while debgging
		privKey = hashlib.sha512(passwd).digest()[:32]
		return highlevelcrypto.decrypt(data, privKey.encode('hex'))

	# Add the new queue entry with a unix timestamp and chop items older than the max age
	# note - the queue is never cleared as there can be multiple clients, it's just chopped to maxage
	def queueAdd(self, key, val, peer = ''):
		ts = self.app.timestamp()
		item = (key,ts,val,peer)
		self.queue.append(item)
		self.queue = filter(lambda f: ts - f[1] < self.app.maxage, self.queue)
		print 'Change queued: ' + str(item)

	# Get all the changes since the specified time
	def queueGet(self, since = 0):
		return filter(lambda f: f[1] > since, self.queue)

	# Merge the passed items with the queue
	def queueMerge(self, cdata, ts):
		sdata = {}
		for (k,t,v,i) in cdata + self.queueGet(ts):
			if not(k in sdata and t < sdata[k][0]): sdata[k] = (t,v,i)
		self.queue = []
		for k in sdata:
			item = (k,sdata[k][0],sdata[k][1],sdata[k][2])
			self.queue.append(item)
		return self.queue
		
