class Node:
	"""User and Group classes inherit this functionality so they can have a persistent properties structure"""

	data = None # cache of this node's data

	# Get a property in this nodes data structure
	def get(self, key):

		# Load the data if the cache is uninitialised
		if self.data == None:
			self.load()

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
		if self.data == None:
			self.load()

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
		j[leaf] = val

		# Save the updated data
		self.save()

	# Get the filesystem location of this node's data
	def path(self):
		return app.data + '/' + self.addr + '.json'

	# Load this node's data into the local cache
	def load(self):
		f = self.path()

		# Create the file if it doesn't exist
		if os.path.exists(f):
			h = open(f, "rb")
			self.data = json.loads(h.read())
		else:
			s = '{}'
			self.data = json.loads(s)
			h = open(f, "wb+")
			h.write(s);
		h.close()

	# Save the local cache to the data file
	def save(self):
		f = self.path()
		h = open(f, "wb+")
		h.write(json.dumps(self.data));
		h.close()

	# Delete this node's data
	def delete(self):
		f = self.path()
		if os.path.exists(f):
			os.remove(f)
