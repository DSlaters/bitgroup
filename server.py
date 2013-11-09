import os, re, time, struct, glob
import socket, asyncore, asynchat
import urllib, hashlib, json, mimetypes, email.utils
from group import *

class Server(asyncore.dispatcher):
	"""
	Create a listening socket server for the interfaces and peers to connect to
	"""
	host      = None
	port      = None
	lastState = None    # The last application state that was sent to the interface clients (json)

	# This contains a key for each active client ID, each is a Client or Connection object
	clients   = {}

	"""
	Set up the listener
	"""
	def __init__(self, host, port):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((host, port))
		self.setblocking(1)
		self.listen(5)
		self.host = host
		self.port = port
		app.log("Server listening on port " + str(port))

	"""
	Accept a new incoming connection and set up a new connection handler instance for it
	"""
	def handle_accept(self):
		sock, addr = self.accept()
		Connection(self, sock)

	"""
	Push a change to interface connections
	"""
	def pushInterfaceChanges(self, group, changes, excl = -1):
		if group: app.log("Broadcasting changes to INTERFACE clients in group \"" + group.name + "\"")
		else: app.log("Broadcasting STATE changes to INTERFACE clients in all groups")
		for k in app.server.clients.keys():
			client = app.server.clients[k]
			if client.role is INTERFACE and (client.group is group or group is None) and k != excl:
				data = json.dumps(changes)
				if client.proto is WEBSOCKET: client.wsSend(data)
				elif client.proto is XMLSOCKET: client.swfSend(data)
				else: app.log("Unknown INTERFACE protocol")

	"""
	Push a change to peer connections
	"""
	def pushPeerChanges(self, group, changes, excl = -1):
		app.log("Broadcasting changes to PEER clients in group \"" + group.name + "\"")
		for k in app.server.clients.keys():
			client = app.server.clients[k]
			if client.role is PEER and client.group is group and k != excl:
				client.peerSendMessage(CHANGES, changes)

	"""
	TODO: OBSOLETE - this should be handled by the normal changes propagation
	"""
	def pushState(self):
		state = json.dumps({"state": app.state})
		changed = self.lastState != state
		self.lastState = state
		for k in self.clients.keys():
			client = app.server.clients[k]
			if client.role is INTERFACE:

				# Send the application state to this interface client if it changed since last sent
				if changed:
					app.log("Sending status to INTERFACE:" + k)
					client.push(state + '\0')
				
				# Extract any unsent messages that are for this interface client's group
				data = {}
				for msgID in app.inbox:
					msg = app.inbox[msgID]
					if not msg['sent']:
						if msg['group'] is None: data[msgID] = msg
						elif client.group and msg['group'] is client.group.prvaddr: data[msgID] = msg
				
				# Send the extracted messages to this interface client if any and mark as sent
				messages = len(data.keys())
				if messages > 0:
					app.log("Sending " + str(messages) + " new messages to INTERFACE:" + k)
					client.push(json.dumps({"state":{"inbox":data}}) + '\0')
					for msgID in app.inbox: app.inbox[msgID]['sent'] = True

	"""
	Send a message to all peers in the passed group
	"""
	def groupBroadcast(self, group, msgType, msg, excl = -1):
		app.log("Broadcasting " + app.cname(msgType) + " message to \"" + group.name + "\"")
		for k in self.clients.keys():
			client = app.server.clients[k]
			if client.role is PEER and client.group is group and k != excl:
				client.conn.peerSendMessage(msgType, msg)
					
class Client:
	"""
	Class to contain the data aspect of a connection
	- also allows clients in the server.clients list that have no active connection if instantiated directly
	"""
	role   = None  # Whether this is a local interface or remote peer (for persistent connections)
	group  = None  # The group this connection is associated with (for persistent connections)

class Connection(asynchat.async_chat, Client):
	"""
	Handles incoming data requests for a single connection
	"""
	server  = None        # Gives the connection handler access to the server properties such as the client data array
	client  = None        # Client ID for persistent connections
	proto   = None        # XMLSOCKET ot WEBSOCKET for persistent connections
	sock    = None        # The socket object for this connection
	data    = ""          # Data accumulates here until a complete message has arrived

	status  = '200 OK'    # HTTP status code returned to client
	content = ''          # HTTP content returned to client
	clen    = 0           # HTTP content length returned to client
	ctype   = 'text/html' # HTTP content type returned to client

	"""
	Set up the connection handler (we use no terminator as we're detecting and removing completed messages manually)
	"""
	def __init__(self, server, sock):
		asynchat.async_chat.__init__(self, sock)
		self.server = server
		self.sock = sock
		self.set_terminator(None)
		self.request = None
		self.shutdown = 0

	"""
	When the socket closes (from the remote end), remove self from the active clients list
	"""
	def handle_close(self):
		asyncore.dispatcher.handle_close(self)
		for k in self.server.clients.keys():
			client = self.server.clients[k]
			if client is self:
				del self.server.clients[k]
				app.log("Connection closed from remote end, client \"" + k + "\" removed from active client data")
				if client.role == PEER: client.group.peerDel(k, False)

	"""
	New data has arrived, accumulate the data and remove messages for processing as they're completed
	"""
	def collect_incoming_data(self, data):
		self.data += data

		# Check if it's data on an already established WebSocket connection
		if self.proto is WEBSOCKET:
			self.wsData(self.data)
			self.data = ""
			return

		# Check if the data is a WebSocket connection request
		match = re.match('GET /(.+?) HTTP/1.1.+Sec-WebSocket-Key: (.+?)\s', self.data, re.S)
		if match:
			client = match.group(1)
			key = match.group(2)
			self.wsAcceptConnection(client, group, key)
			self.data = ""
			return

		# If the data starts with < and contains a zero byte, then it's a message from on an interface XmlSocket
		match = re.match('<.+?\0', self.data, re.S)
		if match:
			msg = match.group(0)
			dl = len(self.data)
			cl = len(msg)
			if dl > cl: self.data = data[cl:]
			else: self.data = ""
			self.swfProcessMessage(msg)
			return

		# If the data starts with Bitgroup:peer:type\nMSG\0, then it's a message from a peer
		match = re.match(app.name + "-([0-9.]+):(.+?):(\w+)\n(.+?)\0", self.data)
		if match:
			peer = match.group(2)
			msgType = match.group(3)
			msg = match.group(4)
			dl = len(self.data)
			cl = len(match.group(0))
			if dl > cl: self.data = data[cl:]
			else: self.data = ""
			self.peerProcessMessage(msgType, msg)
			return

		# Check if there's a full header in the content, and if so if content-length is specified and we have that amount
		match = re.match(r'.+\r\n\r\n', self.data, re.S)
		if match:
			msg = False
			head = match.group(0)
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

			# If we have a complete HTTP message, process it
			if msg: self.httpProcessMessage(msg)
			return

		app.log("Unintelligable message: " + data)

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

			# Check if the request is authorised and return auth request if not
			if not self.httpAuthenticate(head, method): return self.httpSendAuthRequest()

			# If the uri starts with a group addr, set group and change path to group's files
			m = re.match('/(BM-.+?)($|/.*)', uri)
			if m:
				group = Group(m.group(1)) if m else None
				if not group.addr: group = None
				if group:
					if m.group(2) == '/' or m.group(2) == '': uri = '/'
					else:
						docroot = app.datapath
						uri = '/' + group.prvaddr + '/files' + m.group(2)
			else: group = None
			self.group = group if group else app.user
			uri = os.path.abspath(uri)
			path = docroot + uri
			base = os.path.basename(uri)

			# Serve the main HTML document if its a root request
			if uri == '/': self.httpDefaultDocument()

			# If this is a client registration request, add it to the server's list of active clients
			elif base == '_register': self.httpRegisterClient(head)

			# If this is a new group creation request call the newgroup method and return the sanitised name
			elif base == '_newgroup.json': self.httpNewGroup(data)

			# Serve the requested file if it exists and isn't a directory
			elif os.path.exists(path) and not os.path.isdir(path): self.httpGetFile(uri, path)

			# Return a 404 for everything else
			else: self.httpNotFound(uri)

			# Build the HTTP headers and send the content
			if self.clen == 0: self.clen = len(self.content)
			header = "HTTP/1.1 " + self.status + "\r\n"
			header += "Date: " + time.strftime("%a, %d %b %Y %H:%M:%S %Z") + "\r\n"
			header += "Server: " + app.title + "\r\n"
			header += "Content-Type: " + self.ctype + "\r\n"
			header += "Connection: keep-alive\r\n"
			header += "Content-Length: " + str(self.clen) + "\r\n\r\n"
			self.push(str(header))
			self.push(self.content)
			self.close_when_done()

	"""
	Register a newly loaded interface client page
	"""
	def httpRegisterClient(self, head):
		match = re.search(r'X-Bitgroup-ID: (.+?)\s', head, re.S)
		if match:
			client = match.group(1)
			clients = self.server.clients
			if client in clients:
				app.log("Warning client \"" + client + "\" is already registered")
			else:

				# Register client
				app.log("Client \"" + client + "\" is registered to \"" + self.group.name + "\", waiting for XmlSocket or WebSocket connection")
				clients[client] = Client()
				clients[client].group = self.group
				clients[client].role = INTERFACE

				# Return the group's data
				self.ctype = mimetypes.guess_type('x.json')[0]
				self.content = self.group.json()

		else: app.log("Client registration attempted, but no identification header found")

	"""
	Client has requested creation of a new group
	"""
	def httpNewGroup(self, data):
		self.ctype = mimetypes.guess_type('x.json')[0]
		data = json.loads(data);
		app.log("Creating new group \"" + data['name'] + "\"");
		self.content = json.dumps(app.newGroup(data['name']));

	"""
	Check whether the HTTP request is authenticated
	"""
	def httpAuthenticate(self, head, method):
		match = re.search(r'Authorization: Digest (.+?)\r\n', head)
		if not match:
			app.log("No authentication found in header")
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
		
		if not auth: app.log("Authentication failed!")
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
		app.log("Authentication request sent to client")

	"""
	Return the main default HTML document
	"""
	def httpDefaultDocument(self):
		tmp = {
			'group': False if self.group.isUser else self.group.prvaddr,
			'user': {'lang': app.user.lang, 'groups': {}, 'name': app.user.name},
			'const': constants,
			'ext': self.getExtensions()
		}

		# Get the addresses and names of the user's groups
		for g in app.groups: tmp['user']['groups'][app.groups[g].prvaddr] = app.groups[g].name

		# Build the page content
		content = "<!DOCTYPE html>\n<html lang=\"en\">\n\t<head>\n"
		content += "\t\t<title>" + self.group.name + ' - ' + app.name + "</title>\n"
		content += "\t\t<meta charset=\"UTF-8\" />\n"
		content += "\t\t<meta name=\"generator\" content=\"" + app.title + "\" />\n"
		content += self.addScript("window.tmp = " + json.dumps(tmp) + ";", True)
		content += self.addScript("/resources/jquery-1.10.2.min.js")
		content += self.addStyle("/resources/jquery-ui-1.10.3/themes/base/jquery-ui.css")
		content += self.addScript("/resources/jquery-ui-1.10.3/ui/jquery-ui.js")
		content += self.addScript("/resources/jquery.observehashchange.min.js")
		content += self.addScript("/resources/math.uuid.js")
		content += self.addScript("/main.js")
		content += "\t</head>\n\t<body></body>\n</html>"
		self.content = str(content)

	def addScript(self, js, inline = False):
		html = "\t\t<script type=\"text/javascript\""
		if inline: html += ">" + js
		else: html += " src=\"" + js + "\">"
		html += "</script>\n"
		return html

	def addStyle(self, css):
		return "\t\t<link rel=\"stylesheet\" href=\"" + css + "\" />\n"

	"""
	Return the paths for all extensions for this group
	"""
	def getExtensions(self):
		allexts = []

		# Built in extensions
		for js in glob.glob(app.docroot + '/includes/*.js'):
			allexts.append("/includes/" + os.path.basename(js))

		# This group's extensions
		exts = self.group.getData('settings.extensions')
		if exts:
			for ext in exts:
				allexts.append("/extensions/" + ext + '.js')
			
		return allexts

	"""
	Get a file from the specified URI and path info
	"""
	def httpGetFile(self, uri, path):
		self.ctype = mimetypes.guess_type(uri)[0]
		self.clen = os.path.getsize(path)
		fh = open(path, "rb")
		self.content = fh.read()
		fh.close()

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
		self.content = str(content)

	"""
	Process a completed message from an interface XmlSocket
	"""
	def swfProcessMessage(self, msg):

		# Check if this is the SWF asking for the connection policy, and if so, respond with a policy restricted to this host and port
		if msg == '<policy-file-request/>\x00':
			self.swfReturnPolicy()
			return

		# Check if this is a SWF giving its client id so that we can associate the socket with it
		match = re.match('<client-id>(.+?)</client-id>', msg)
		if match:
			client = match.group(1)
			self.swfAcceptConnection(client)
			return

		# Check if this is data being sent from an interface through the XmlSocket
		match = re.match('<data>(.+?)</data>', msg)
		if match:
			data = json.loads(match.group(1));
			self.swfData(data)

	"""
	A new XmlSocket connection has requested its policy file
	"""
	def swfReturnPolicy(self):
		# TODO: policy = '<allow-access-from domain="' + self.server.host + '" to-ports="' + str(self.server.port) + '" />'
		policy = '<allow-access-from domain="*" to-ports="*" />'
		policy = '<cross-domain-policy>' + policy + '</cross-domain-policy>'
		self.push(policy)
		self.close_when_done()
		app.log('SWF policy sent.')

	"""
	a new XmlSocket connection is identifying itself
	"""
	def swfAcceptConnection(self, client):
		clients = self.server.clients

		# Deny the connection if it's not registered
		if not client in clients:
			app.log("A new XmlSocket connection for client \"" + client + "\" was denied because the client is not registered.")
			self.close()
			return

		# Set the group to that given in registration and replace the dummy client with the real connection
		self.group = clients[client].group
		clients[client] = self
		self.role = INTERFACE
		self.proto = XMLSOCKET
		self.client = client
		app.log("XmlSocket connected for client \"" + client + "\" in group \"" + self.group.name + "\"")

	"""
	Changes data has been received on an XmlSocket
	"""
	def swfData(self, data):
		app.log("Changes received from XmlSocket \"" + self.client + "\"")
		for item in data: self.group.setData(item[0], item[1], item[2], item[3], self.client)

	"""
	Send changes to an XmlSocket
	"""
	def swfSend(seld, data):
		self.push(data + '\0')

	"""
	TODO: Process a completed JSON message from a peer
	"""
	def peerProcessMessage(self, peer, msgType, msg):
		clients = self.server.clients
		if peer in clients: client = clients[peer]
		else:
			app.log("Message received from unknown peer \"" + peer + "\": " + str(self.sock))
			return
		if not client.role is PEER:
			app.log("Message received from a non-peer client \"" + peer + "\": " + str(self.sock))
			return
		group = client.group

		# Try and decrypt the peer's message
		try:
			data = json.loads(app.decrypt(msg.decode('base64'), group.passwd))
		except:
			app.log("Invalid data received from remote peer: " + str(self.sock))
			return

		# This is a changes messge, or another message type that contains changes
		if CHANGES in data:
			for item in data[CHANGES]: group.set(item[0], item[1], item[2], peer)
			app.log("Changes received from " + peer + str(data[CHANGES]) )

		# This is a Welcome message (repsonse to a Presence message we sent)
		if msgType is WELCOME:

			# If peer information was sent, store in the group data
			if PEER in data: group.peers = data[PEER]

		# This is a change of status message (e.g. availability change etc) from another peer, or from the server regarding a peer
		# TODO: This will be processed in normal changes messages now
		if msgType is STATUS:
			# TODO: save in client data, and if we're the server, send the updated info to the other peers
			
			# Information has been sent for one or more peers to be updated
			if PEER in data:
				for k in data[PEER].keys():
					if k in group.peers:
						info = data[PEER][k]

						# A peer with no info means that it shouls be removed
						if info is None: group.peerDel(k)
							
						# Otherwise just update this peers data
						else: group.peers[k] = info

					# We log an error if the peer isn't in the groups list becasue all should have the peers info either from the
					# Presence message it sent when it came online, or from the Welcome message we received in response to our
					# initial Presence message when we went online
					else: app.log("We were sent a message by \"" + peer + "\" to update peer \"" + k + "\" for group \"" + group.name + "\", but that peer isn't in the peers array")

	"""
	Send a message to a peer
	"""
	def peerSendMessage(self, msgType, msg):
		if not self.role is PEER:
			app.log("Non-peer cannot use sendPeerMessage: \"" + peer + "\": " + str(self.sock))
			return
		self.push(app.title + ': ' + msgType + '\n' + app.encrypt(json.dumps(msg), self.group.passwd).encode('base64') + '\0')

	"""
	Respond to a WebSocket connection request from an interface client
	"""
	def wsAcceptConnection(self, client, group, key):

		# Return the expected response to establish the WebSocket
		accept = hashlib.sha1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest().encode('base64').strip()
		response = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
		response += "Upgrade: websocket\r\n"
		response += "Connection: Upgrade\r\n"
		response += "Sec-WebSocket-Accept: " + accept + "\r\n"
		response += "Sec-WebSocket-Protocol: sample\r\n\r\n"
		self.push(response)

		# Check if this ID is registered (in a list of ID's from HTTP headers that have passed authentication)
		clients = self.server.clients
		if not client in clients:
			app.log("A new WebSocket connection for client \"" + client + "\" was denied because the client is not registered.")
			self.close()
			return

		# Set the group to that given in registration and replace the dummy client with the real connection
		self.group = clients[client].group
		clients[client] = self
		self.role = INTERFACE
		self.proto = WEBSOCKET
		self.client = client
		app.log("WebSocket connected for client \"" + client + "\" in group \"" + self.group.name + "\"")

	"""
	Data received from a WebSocket connection
	"""
	def wsData(self, data):
	
		# Decode the data
		byteArray = [ord(character) for character in data]
		datalength = byteArray[1] & 127
		indexFirstMask = 2 
		if datalength == 126: indexFirstMask = 4
		elif datalength == 127: indexFirstMask = 10
		masks = byteArray[indexFirstMask:indexFirstMask + 4]
		decoded = ''
		i = indexFirstMask + 4
		j = 0
		while i < len(byteArray):
			decoded += chr(byteArray[i] ^ masks[j % 4])
			i += 1
			j += 1

		# TODO: Needs fixing - when clients refresh, the connection sends an 8 byte message that decodes to 2,233
		if len(decoded) < 3:
			app.log("WebSocket message from \"" + self.client + "\" ignored: too short")
			return

		# Process the message
		app.log("Changes received over WebSocket from client \"" + self.client + "\": " + decoded)
		data = json.loads(decoded);
		for item in data: self.group.setData(item[0], item[1], item[2], item[3], self.client)

	"""
	Send changes to a WebSocket connection
	"""
	def wsSend(self, bytesRaw):
		bytesFormatted = []
		bytesFormatted.append(struct.pack('B', 129))
		if len(bytesRaw) <= 125:
			bytesFormatted.append(struct.pack('B', len(bytesRaw)))
		elif len(bytesRaw) >= 126 and len(bytesRaw) <= 65535:
			bytesFormatted.append(struct.pack('B', 126));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw) >> 8 ) & 255));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw)      ) & 255));
		else:
			bytesFormatted.append(struct.pack('B', 127));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw) >> 56 ) & 255));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw) >> 48 ) & 255));
			bytesFormatted.append(struct.pack('B', (len( bytesRaw) >> 40 ) & 255));
			bytesFormatted.append(struct.pack('B', (len( bytesRaw) >> 32 ) & 255));
			bytesFormatted.append(struct.pack('B', (len( bytesRaw) >> 24 ) & 255));
			bytesFormatted.append(struct.pack('B', (len( bytesRaw) >> 16 ) & 255));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw) >>  8 ) & 255));
			bytesFormatted.append(struct.pack('B', ( len(bytesRaw)       ) & 255));
		for i in range(len(bytesRaw)):
			bytesFormatted.append(struct.pack('B', ord(bytesRaw[i])))
		self.push(b''.join(bytesFormatted));
