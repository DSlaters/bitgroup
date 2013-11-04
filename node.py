import os, json, string
from message import *

class Node:
	"""
	User and Group classes inherit this functionality so they can have a persistent properties structure.
	The data is stored encrypted using the encryption functions directly from the PyBitmessage source.
	"""
	data = None       # cache of this node's data
	passwd = None     # used to ecrypt data and messages for this user or group
	queue = {}        # cache of key : [val, ts, client] for sending changes to clients on sync requests
	lastSend = None   # Last time this group's changes were broadcast to the members

	"""
	TODO: Get a list of keys in the data within the given path and zone
	"""
	def getKeys(self, path = None, zone = None):
		
		# Load the data if the cache is uninitialised
		if self.data == None: self.load()



	"""
	Get a property in this nodes data structure (with timestamp and zone info if 'all' set)
	"""
	def getData(self, key, all = False):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

		# Split key path and walk data path to get value
		val = self.data
		for i in key.split('.'):
			if type(val) == dict and i in val: val = val[i]
			else: return None

		# Add DATA zone if no zone data
		if len(val) == 2: val.append(DATA)

		return val if all else val[0]

	"""
	Set a property in this nodes data structure
	"""
	def setData(self, zone, key, val, ts = None, client = ''):
		if ts is None: ts = app.timestamp()
		path = key.split('.')
		leaf = path.pop()

		# Load the data if the cache is uninitialised
		if self.data is None: self.load()

		# Split key path and walk data path to set value, create non-existent items
		j = self.data
		for i in path:
			if type(j) is dict and i in j: j = j[i]
			else:
				if not type(j) is dict:
					app.log("Failed to set " + key + " as a value already exists at path element '" + i + "'")
					return None
				j[i] = {}
				j = j[i]

		if not type(j) is dict:
			app.log("Failed to set " + key + " as a value already exists at path element '" + i + "'")
			return None

		# If the value already exists get the current value and timestamp and store only if more recent
		if leaf in j:
			if ts > j[leaf][1]: changed = json.dumps(j[leaf][0]) != json.dumps(val)
			else: changed = False
		else: changed = True

		# If the data should change, propagate/store/queue the change depending on the root element of the key
		if changed:

			# Update the local cache, and interface clients unconditionally (if zone is STATE, send to interfaces in any group)
			j[leaf] = [val, ts, zone]
			app.server.pushInterfaceChanges(None if zone is STATE else self, [[zone, key, val, ts]], client)

			# Queue the change for periodic sending unless its specific to online peers
			# - we include interface-only data because the interface may be Ajax-only,
			#   but we need to filter these when sending the change to peers via Bitmessage
			if not zone is PEER: self.queue[key] = [val, ts, client]

			# Push the change to all peers unless it's specifically for interfaces only or its not in group context (a user change)
			if not ( zone is INTERFACE or self.isUser ): app.server.pushPeerChanges(self, [[zone, key, val, ts]], client)

			# Update the stored data only if the zone is DATA
			if zone is DATA: self.save()

		# Return state of change
		return changed

	"""
	TODO
	"""
	def remove(self):

		# Load the data if the cache is uninitialised
		if self.data == None: self.load()

	"""
	Get the filesystem location of this node's data
	"""
	def path(self):
		return app.datapath + '/' + self.prvaddr + '.json'

	"""
	Load this node's data into the local cache
	"""
	def load(self):
		f = self.path()
		if os.path.exists(f):
			h = open(f, "rb")
			#self.data = self.decrypt(json.loads(h.read()), self.passwd)
			self.data = json.loads(h.read())
			h.close()
		else: self.data = {}
		return self.data;

	"""
	Save the local cache to the data file
	TODO: data changes should queue and save periodically, not on every property change
	"""
	def save(self):
		f = self.path()
		h = open(f, "wb+")
		#h.write(self.encrypt(json.dumps(self.data), self.passwd));
		h.write(json.dumps(self.data));
		h.close()

	"""
	Return the data as JSON for the interface
	"""
	def json(self):
		if self.data == None: self.load()
		data = self.data

		# We need to include the state data if this is not the user (TODO: use self.keys when done)
		if not self.isUser:
			for k in app.user.data:
				i = app.user.data[k]
				if len(i) == 3 and i[2] == STATE:
					data[k] = i

		return json.dumps(data)

	"""
	Return a list of changes since a specified time and, (if a client is specified) that did not originate from that client
	"""
	def changes(self, since, excl = -1):
		changes = []
		for k in filter(lambda f: self.queue[f][1] > since and (excl == -1 or self.queue[f][2] != excl), self.queue):
			changes.append([k, self.queue[k][0], self.queue[k][1]])
		return changes

	"""
	TODO: Send queued changes since last send to the group's private Bitmessage address
	"""
	def sendChanges(self):
		data = self.changes(self.lastSend)
		msg = Changes(self)
		msg.send()
		self.lastSend = app.timestamp()
