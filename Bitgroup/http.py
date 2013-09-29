import os
import socket
import asyncore, asynchat
import time
import re
import mimetypes
import struct
import urllib
import hashlib
import json

class server(asyncore.dispatcher):
	"""
	Create a listening socket server for the interface JavaScript and SWF components to connect to
	"""

	host = None
	port = None

	# This contains a key for each active client ID, and each key contains "lastSync" and "swfSocket"
	clients = {}

	# Set up the listener
	def __init__(self, host, port):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((host, port))
		self.setblocking(1)
		self.listen(5)
		self.host = host
		self.port = port

	# Accept a new incoming connection and set up a new handler instance for it
	def handle_accept(self):
		sock, addr = self.accept()
		handler(self, sock)


class handler(asynchat.async_chat):
	"""
	Handles incoming data requests for a single connection
	"""

	server = None  # Gives the handler access to the server properties such as the client data array
	data = ""      # Data accumulates here until a complete message has arrived

	status = None  # HTTP status code returned to client
	ctype  = None  # HTTP content type returned to client
	clen = None    # HTTP content length returned to client

	"""
	Set up the handler (we use no terminator as we're detecting and removing completed messages manually)
	"""
	def __init__(self, server, sock):
		asynchat.async_chat.__init__(self, sock)
		self.server = server
		self.set_terminator(None)
		self.request = None
		self.shutdown = 0

	"""
	When the socket closes, remove self from the swfSocket list if in there
	"""
	def handle_close(self):
		asyncore.dispatcher.handle_close(self)
		for client in self.server.clients.keys():
			data = self.server.clients[client]
			if 'swfSocket' in data and data['swfSocket'] is self:
				del self.server.clients[client]
				print "Socket closed, client " + client + " removed from data"

	"""
	New data has arrived, accumulate the data and remove messages for processing as they're completed
	"""
	def collect_incoming_data(self, data):
		self.data += data
		msg = False

		# If the data starts with < and contains a zero byte, then it's an XML message from a local SWF socket
		match = re.match('(<.+?\0)', self.data, re.S)
		if match:
			msg = match.group(1)
			dl = len(self.data)
			cl = len(msg)
			if dl > cl: self.data = data[cl:]
			else: self.data = ""
			self.swfProcessMessage(msg)

		# If the data starts with { and contains a zero byte, then it's a JSON message from a remote peer
		match = re.match('(\{.+?\0)', self.data, re.S)
		if match:
			msg = match.group(1)
			dl = len(self.data)
			cl = len(msg)
			if dl > cl: self.data = data[cl:]
			else: self.data = ""
			self.peerProcessMessage(msg)

		# Check if there's a full header in the content, and if so if content-length is specified and we have that amount
		match = re.match(r'(.+\r\n\r\n)', self.data, re.S)
		if match:
			head = match.group(1)
			data = ""
			match = re.search(r'content-length: (\d+).*?\r\n\r\n(.*)', self.data, re.I|re.S)
			if match:
				data = match.group(2)
				dl = len(data)
				cl = int(match.group(1))
				if dl >= cl:

					# Finished a head+content message, if we have more than the content length, start a new message
					msg = head + data[:cl]
					if dl > cl: self.data = data[cl:]
					else: self.data = ""
			else:

				# Finished a head-only message, anything after the head is part of a new message
				msg = head
				self.data = data
				done = True

		# If we have a complete message:
		if msg: self.httpProcessMessage(msg)

	"""
	Process a completed HTTP message (including header and digest authentication) from a JavaScript client
	"""
	def httpProcessMessage(self, msg):
		match = re.match(r'^(GET|POST) (.+?)(\?.+?)? HTTP.+Host: (.+?)\s(.+?\r\n\r\n)\s*(.*?)\s*$', msg, re.S)
		if match:
			method = match.group(1)
			uri = urllib.unquote(match.group(2)).decode('utf8') 
			host = match.group(4)
			head = match.group(5)
			data = match.group(6)
			docroot = app.docroot
			self.status = "200 OK"
			self.ctype = "text/html"
			self.clen = 0

			# Check if the request is authorised and return auth request if not
			if not self.httpIsAuthenticated(head, method): return self.httpSendAuthRequest()

			# If the uri starts with a group addr, set group and change path to group's files
			m = re.match('/(.+?)($|/.*)', uri)
			if m and m.group(1) in app.groups:
				group = m.group(1)
				if m.group(2) == '/' or m.group(2) == '': uri = '/'
				else:
					docroot = app.datapath
					uri = '/' + group + '/files' + m.group(2)
			else: group = ''
			uri = os.path.abspath(uri)
			path = docroot + uri
			base = os.path.basename(uri)

			# Serve the main HTML document if its a root request
			if uri == '/': content = self.httpDefaultDocument(group)

			# If this is a new group creation request call the newgroup method and return the sanitised name
			elif base == '_newgroup.json':
				self.ctype = mimetypes.guess_type(base)[0]
				content = json.dumps(app.newGroup(json.loads(data)['name']));

			# If this is a for _sync.json merge the local and client change queues and return the changes
			elif base == '_sync.json': content = self.httpSyncData(head, data, base, group)

			# Serve the requested file if it exists and isn't a directory
			elif os.path.exists(path) and not os.path.isdir(path): content = self.httpGetFile(uri, path)

			# Return a 404 for everything else
			else: content = self.httpNotFound(uri)

			# Build the HTTP headers and send the content
			if self.clen == 0: self.clen = len(content)
			header = "HTTP/1.1 " + self.status + "\r\n"
			header += "Date: " + time.strftime("%a, %d %b %Y %H:%M:%S %Z") + "\r\n"
			header += "Server: " + app.title + "\r\n"
			header += "Content-Type: " + self.ctype + "\r\n"
			header += "Connection: keep-alive\r\n"
			header += "Content-Length: " + str(self.clen) + "\r\n\r\n"
			self.push(str(header))
			self.push(content)
			self.close_when_done()

	"""
	Check whether the HTTP request is authenticated
	"""
	def httpIsAuthenticated(self, head, method):
		match = re.search(r'Authorization: Digest (.+?)\r\n', head)
		if not match:
			print "No authentication found in header"
			return False

		# Get the client's auth info
		digest = match.group(1)
		match = re.search(r'username="(.+?)"', digest)
		authuser = match.group(1) if match else ''
		match = re.search(r'nonce="(.+?)"', digest)
		nonce = match.group(1) if match else ''
		match = re.search(r'nc=(.+?),', digest)
		nc = match.group(1) if match else ''
		match = re.search(r'cnonce="(.+?)"', digest)
		cnonce = match.group(1) if match else ''
		match = re.search(r'uri="(.+?)"', digest)
		authuri = match.group(1) if match else ''
		match = re.search(r'qop=(.+?),', digest)
		qop = match.group(1) if match else ''
		match = re.search(r'response="(.+?)"', digest)
		res = match.group(1) if match else ''

		# Build the expected response and test against client response
		A1 = hashlib.md5(':'.join([app.user.iuser,app.title,app.user.ipass])).hexdigest()
		A2 = hashlib.md5(':'.join([method,authuri])).hexdigest()
		ok = hashlib.md5(':'.join([A1,nonce,nc,cnonce,qop,A2])).hexdigest()
		auth = res == ok
		
		if not auth: print "Authentication failed!"
		return auth

	"""
	Return a digest authentication request to client
	"""
	def httpSendAuthRequest(self):
		content = app.msg('authneeded')
		uuid = hashlib.md5(str(app.timestamp()) + app.user.addr).hexdigest()
		md5 = hashlib.md5(app.title).hexdigest()
		header = "HTTP/1.1 401 Unauthorized\r\n"
		header += "WWW-Authenticate: Digest realm=\"" + app.title + "\",qop=\"auth\",nonce=\"" + uuid + "\",opaque=\"" + md5 + "\"\r\n"
		header += "Date: " + time.strftime("%a, %d %b %Y %H:%M:%S %Z") + "\r\n"
		header += "Server: " + app.title + "\r\n"
		header += "Content-Type: text/plain\r\n"
		header += "Content-Length: " + str(len(content)) + "\r\n\r\n"
		self.push(str(header + content))
		self.close_when_done()
		print "Authentication request sent to client"

	"""
	Return the main default HTML document
	"""
	def httpDefaultDocument(self, group):
		tmp = {
			'group': group,
			'user': {'lang': app.user.lang, 'groups': {}},
		}

		# Get the addresses and names of the user's groups
		for i in app.groups: tmp['user']['groups'][i] = app.groups[i].name

		# Get the group's extensions
		if group in app.groups: tmp['ext'] = app.groups[group].get('settings.extensions')
		else: tmp['ext'] = []

		# Build the page content
		content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
		content += "<title>" + ( group + " - " if group else '' ) + app.name + "</title>\n"
		content += "<meta charset=\"UTF-8\" />\n"
		content += "<meta name=\"generator\" content=\"" + app.title + "\" />\n"
		content += "<script type=\"text/javascript\">window.tmp = " + json.dumps(tmp) + ";</script>\n"
		content += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
		content += "<link rel=\"stylesheet\" href=\"/resources/jquery-ui-1.10.3/themes/base/jquery-ui.css\" />\n"
		content += "<script type=\"text/javascript\" src=\"/resources/jquery-ui-1.10.3/ui/jquery-ui.js\"></script>\n"
		content += "<script type=\"text/javascript\" src=\"/resources/jquery.observehashchange.min.js\"></script>\n"
		content += "<script type=\"text/javascript\" src=\"/resources/math.uuid.js\"></script>\n"
		content += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
		content += "<script type=\"text/javascript\" src=\"/overview.js\"></script>\n"
		content += "<script type=\"text/javascript\" src=\"/newgroup.js\"></script>\n"
		content += "</head>\n<body>\n</body>\n</html>\n"
		return str(content)

	"""
	Process a DataSync request from an HTTP client
	"""
	def httpSyncData(self, head, data, base, group):
		if group in app.groups:
			clients = self.server.clients
			now  = app.timestamp()
			self.ctype = mimetypes.guess_type(base)[0]
			cdata = []
			g = app.groups[group]

			# Identify the client stream using a unique ID in the header
			match = re.search(r'X-Bitgroup-ID: (.+?)\s', head)
			client = match.group(1) if match else ''
			if not client in clients: clients[client] = {}

			# Get the timestamp of the last time this client connected and update
			if client in clients and 'lastSync' in clients[client]: ts = clients[client]['lastSync']
			else: ts = 0
			clients[client]['lastSync'] = now

			# If the client sent change-data merge into the local data
			if data:
				cdata = json.loads(data)
				for item in cdata: g.set(item[0], item[1], item[2], client)
				print "Received from " + client + " (last=" + str(ts) + "): " + str(cdata)

			# Last sync was more than maxage seconds ago, send all data
			if now - ts > app.maxage: content = app.groups[group].json()

			# Otherwise send the queue of changes that have occurred since the client's last sync request
			else:

				# If we have a SWF socket for this client, bail as changes will already be sent
				if 'swfSocket' in clients[client]: content = ''
				else:
					content = g.changes(ts - (now-ts), client) # TODO: messy doubling of period (bug#3)
					if len(content) > 0: print "Sending to " + client + ': ' + json.dumps(content)

					# Put an object on the end of the list containing the application state data
					content.append(app.getStateData())

					# Convert the content to JSON ready for sending to the client
					content = json.dumps(content)

		# No group selected, send only the state data
		else: content = json.dumps([app.getStateData()])
		return content

	"""
	Get a file from the specified URI and path info
	"""
	def httpGetFile(self, uri, path):
		self.ctype = mimetypes.guess_type(uri)[0]
		self.clen = os.path.getsize(path)
		fh = open(path, "rb")
		content = fh.read()
		fh.close()
		return content

	"""
	Return a 404 Not Found document
	"""
	def httpNotFound(self, uri):
		self.status = "404 Not Found"
		content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
		content += "<html><head><title>404 Not Found</title></head>\n"
		content += "<body><h1>Not Found</h1>\n"
		content += "<p>The requested URL " + uri + " was not found on this server.</p>\n"
		content += "</body></html>"
		return str(content)

	"""
	Process a completed XML message from a local SWF instance
	"""
	def swfProcessMessage(self, msg):

		# Check if this is the SWF asking for the connection policy, and if so, respond with a policy restricted to this host and port
		if msg == '<policy-file-request/>\x00':
			policy = '<allow-access-from domain="' + self.server.host + '" to-ports="' + str(self.server.port) + '" />'
			policy = '<cross-domain-policy>' + policy + '</cross-domain-policy>'
			self.push(policy)
			self.close_when_done()
			print 'SWF policy sent.'

		# Check if this is a SWF giving its client id so that we can associate the socket with it
		match = re.match('<client-id>(.+?)</client-id>', msg)
		if match:
			clients = self.server.clients
			client = match.group(1)
			if not client in clients: clients[client] = {}
			clients[client]['swfSocket'] = self
			print "SWF socket identified for client " + client

	"""
	Process a completed JSON message from a remote peer
	"""
	def peerProcessMessage(self, msg):
		# TODO
		pass
