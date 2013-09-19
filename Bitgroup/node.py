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
	queue = {}     # cache of key : [val, ts, client] for sending changes to clients on sync requests

	# Get a property in this nodes data structure (with its timestamo if ts set)
	def get(self, key, ts = False):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

		# Split key path and walk data path to get value
		val = self.data
		for i in key.split('.'):
			if type(val) == dict and i in val: val = val[i]
			else: return None

		return val if ts else val[0]

	# Set a property in this nodes data structure
	def set(self, key, val, ts = None, client = ''):
		if ts == None: ts = self.app.timestamp()

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

		# Split key path and walk data path to set value, create non-existent items
		j = self.data
		path = key.split('.')
		leaf = path.pop()
		for i in path:
			if type(j) == dict and i in j: j = j[i]
			else:
				if not type(j) == dict:
					print "Failed to set " + key + " as a value already exists at path element '" + i + "'"
					return None
				j[i] = {}
				j = j[i]

		# If the value already exists get the current value and timestamp and store only if more recent
		if leaf in j:
			(oldval, oldts) = j[leaf]
			if ts > oldts: changed = json.dumps(oldval) != json.dumps(val)
			else: changed = False
		else: changed = True

		# If the data should change, store the new value in the local cache, update the persistent data and update the client-queue
		if changed:
			j[leaf] = [val, ts]
			self.save()
			self.queue[key] = [val, ts, client]

		# Return state of change
		return changed

	# TODO
	def remove(self):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

	# Get the filesystem location of this node's data
	def path(self):
		return self.app.datapath + '/' + self.prvaddr + '.json'

	# Load this node's data into the local cache
	def load(self):
		f = self.path()
		if os.path.exists(f):
			h = open(f, "rb")
			self.data = self.decrypt(json.loads(h.read()), self.passwd)
			h.close()
		else: self.data = {}
		return self.data;

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

	# Return a list of changes since a specified time that did not originate from the specified client
	def changesForClient(self, client, since):
		changes = []
		for k in filter(lambda f: self.queue[f][1] > since and self.queue[f][2] != client, self.queue):
			changes.append([k, self.queue[k][0], self.queue[k][1]])
		return changes
