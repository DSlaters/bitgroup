class Node:
	"""User and Group classes inherit this functionality so they can have a persistent properties structure"""

	data = None # cache of this node's data

	# Get a property in this nodes data structure
	def get(name):

		# Load the data if the cache is uninitialised
		if self.data === None:
			load()

		return val

	# Set a property in this nodes data structure
	def set(name,val):
		return None

	# Get the filesystem location of this node's data
	def path():
		return app.data + '/' + self.addr

	# Load this node's data into the local cache
	def load():
		f = path()

		# Create the file if it doesn't exist
		if os.path.exists(f):
			h = open(f, "rb")
			self.data = json.loads(h.read())
		else:
			json = '{}'
			self.data = json.loads(json)
			h = open(f, "wb")
			h.write(json);
		h.close()

	# Delete this node's data
	def delete():
		f = path()
		if os.path.exists(f):
			os.remove(f)
