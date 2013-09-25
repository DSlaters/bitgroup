import os
import socket
import asyncore, asynchat
import time
import re
import mimetypes
import json
import struct
import urllib
import hashlib

# Session data stored for each connected client
clientData = {
	'lastSync': {},
	'uuid': None
}



class handler(asynchat.async_chat):

	def __init__(self, server, sock, addr):
		asynchat.async_chat.__init__(self, sock)
		self.set_terminator(None)
		self.request = None
		self.data = ""
		self.shutdown = 0
		self.server = server

	def collect_incoming_data(self, data):
		self.data += data
		msg = False

		# Check if this is the SWF asking for the connection policy
		if self.data == '<policy-file-request/>\x00':
			self.data == ""
			policy = '<allow-access-from domain="' + self.server.host + '" to-ports="' + str(self.server.port) + '" />'
			policy = '<cross-domain-policy>' + policy + '</cross-domain-policy>'
			self.push(policy)
			self.close_when_done()
			print 'SWF policy sent.'
			return

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
		if msg:
			match = re.match(r'^(GET|POST) (.+?)(\?.+?)? HTTP.+Host: (.+?)\s(.+?\r\n\r\n)\s*(.*?)\s*$', msg, re.S)
			if match:
				method = match.group(1)
				uri = urllib.unquote(match.group(2)).decode('utf8') 
				host = match.group(4)
				head = match.group(5)
				data = match.group(6)
				date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
				now  = app.timestamp()
				status = "200 OK"
				ctype = "text/html"
				content = str("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
				clen = 0
				docroot = app.docroot

				# Identify the client stream using a unique ID in the header
				match = re.search(r'X-Bitgroup-ID: (.+?)\s', head)
				client = match.group(1) if match else ''
				if not client in clientData: clientData[client] = {}

				# Check if the request is authorised and return auth request if not
				auth = False
				match = re.search(r'Authorization: Digest (.+?)\r\n', head)
				if match:

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
					auth = (res == ok)

				if not auth:

					# Return auth request
					content = app.msg('authneeded')
					uuid = hashlib.md5(str(app.timestamp()) + app.user.addr).hexdigest()
					md5 = hashlib.md5(app.title).hexdigest()
					header = "HTTP/1.1 401 Unauthorized\r\n"
					header += "WWW-Authenticate: Digest realm=\"" + app.title + "\",qop=\"auth\",nonce=\"" + uuid + "\",opaque=\"" + md5 + "\"\r\n"
					header += "Date: " + date + "\r\n"
					header += "Server: " + app.title + "\r\n"
					header += "Content-Type: text/plain\r\n"
					header += "Content-Length: " + str(len(content)) + "\r\n\r\n"
					clientData[client]['uuid'] = uuid
					self.push(header + content)
					self.close_when_done()
					return

				# If the uri starts with a group addr, set group and change path to group's files
				m = re.match('/(.+?)($|/.*)', uri)
				if m and m.group(1) in app.groups:
					group = m.group(1)
					if m.group(2) == '/' or m.group(2) == '': uri = '/'
					else:
						docroot = app.datapath
						uri = '/' + group + '/files' + m.group(2)
				else: group = ''

				# Serve the main HTML document if its a root request
				uri = os.path.abspath(uri)
				path = docroot + uri
				base = os.path.basename(uri)
				if uri == '/':
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
					content = str(content)

				# If this is a new group creation request call the newgroup method and return the sanitised name
				elif base == '_newgroup.json':
					ctype = mimetypes.guess_type(base)[0]
					content = json.dumps(app.newGroup(json.loads(data)['name']));

				# If this is a for _sync.json merge the local and client change queues and return the changes
				elif base == '_sync.json':
					if group in app.groups:
						ctype = mimetypes.guess_type(base)[0]
						cdata = []
						g = app.groups[group]

						# Get the timestamp of the last time this client connected and update
						if client in clientData and 'lastSync' in clientData[client]: ts = clientData[client]['lastSync']
						else: ts = 0
						clientData[client]['lastSync'] = now

						# If the client sent change-data merge into the local data
						if data:
							cdata = json.loads(data)
							for item in cdata: g.set(item[0], item[1], item[2], client)
							print "Received from " + client + " (last=" + str(ts) + "): " + str(cdata)

						# Last sync was more than maxage seconds ago, send all data
						if now - ts > app.maxage: content = app.groups[group].json()

						# Otherwise send the queue of changes that have occurred since the client's last sync request
						else:
							content = g.changes(ts - (now-ts), client) # TODO: messy doubling of period (bug#3)
							if len(content) > 0: print "Sending to " + client + ': ' + json.dumps(content)

							# Put an object on the end of the list containing the application state data
							content.append(app.getStateData())

							# Convert the content to JSON ready for sending to the client
							content = json.dumps(content)

					else: content = json.dumps([app.getStateData()])

				# Serve the requested file if it exists and isn't a directory
				elif os.path.exists(path) and not os.path.isdir(path):
					ctype = mimetypes.guess_type(uri)[0]
					clen = os.path.getsize(path)
					fh = open(path, "rb")
					content = fh.read()
					fh.close()

				# Return a 404 for everything else
				else:
					status = "404 Not Found"
					content += "<html><head><title>404 Not Found</title></head>\n"
					content += "<body><h1>Not Found</h1>\n"
					content += "<p>The requested URL " + uri + " was not found on this server.</p>\n"
					content += "</body></html>"
					content = str(content)

				# Build the HTTP headers and send the content
				if clen == 0: clen = len(content)
				header = "HTTP/1.1 " + status + "\r\n"
				header += "Date: " + date + "\r\n"
				header += "Server: " + app.title + "\r\n"
				header += "Content-Type: " + ctype + "\r\n"
				header += "Connection: keep-alive\r\n"
				header += "Content-Length: " + str(clen) + "\r\n\r\n"
				self.push(header)
				self.push(content)
				self.close_when_done()

class server(asyncore.dispatcher):

	host = None
	port = None

	def __init__(self, host, port):
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((host, port))
		self.setblocking(0)
		self.listen(5)
		self.host = host
		self.port = port

	def handle_accept(self):
		sock, addr = self.accept()
		handler(self, sock, addr)
