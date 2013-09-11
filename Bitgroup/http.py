# This will be a simple HHTP server to handle requests from the interface (and only the interface)
# it must populate and server the html templates and serve the JS, CSS and image resources
import os
import socket
import asyncore
import time
import re
import mimetypes
import json

class handler(asyncore.dispatcher_with_send):

	def handle_read(self):
		global app
		data = self.recv(8192)
		match = re.match(r'^(GET|POST) (.+?) HTTP.+Host: (.+?)\s(.+?)\r\n\r\n\s*(.*?)\s*$', data, re.S)
		if data and match:
			method = match.group(1)
			uri = match.group(2)
			host = match.group(3)
			head = match.group(4)
			data = match.group(5)
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			server = app.name + "-" + app.version
			status = "200 OK"
			ctype = "text/html"
			content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
			docroot = app.docroot

			# Identify the client stream using a unique ID in the header
			# TODO: There must be a proper way to identify client streams in Python
			match = re.search(r'X-Bitgroup-ID: (.+?)\s', head)
			peer = match.group(1) if match else ''

			# If the uri starts with a group name, set group and change path to group's files
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

				# Get the user data
				user = {'lang': app.user.lang, 'groups': app.groups.keys()}

				# Get the group's extensions (plus default extensions)
				extensions = '';
				extsrc = ['/overview.js']
				if group in app.groups:
					ext = app.groups[group].get('settings.extensions')
					if ext:
						for i in ext:
							extsrc.append('/extensions/' + i + '.js');
				for i in extsrc:
					extensions += '<script type="text/javascript" src="' + i + '"></script>\n';

				# Build the page content
				content += "<title>" + ( group + " - " if group else '' ) + app.name + "</title>\n"
				content += "<meta charset=\"UTF-8\" />\n"
				content += "<meta name=\"generator\" content=\"" + server + "\" />\n"
				content += "<script type=\"text/javascript\">\n"
				content += "window.tmp = {};\n"
				content += "window.tmp.user = " + json.dumps(user) + ";\n"
				content += "window.tmp.group = '" + group + "';\n"
				content += "window.tmp.maxage = " + str(app.maxage) + ";\n"
				content += "</script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-ui-1.10.3/ui/jquery-ui.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery.observehashchange.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/math.uuid.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/i18n.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
				content += extensions
				content += "</head>\n<body>\n</body>\n</html>\n"

			# If this is a request for _data.json return the current group's node data
			elif base == '_data.json':
				if group in app.groups:
					content = app.groups[group].json()
					ctype = mimetypes.guess_type(base)[0]

			# If this is a for _xfer.json merge the local and client change queues and return the changes
			# TODO: merge with timestamps
			# TODO: only delete local queue after acknowledgement of reception
			elif base == '_sync.json':
				if group in app.groups:
					ctype = mimetypes.guess_type(base)[0]
					g = app.groups[group]
					if data:

						# Get the timestamp of the last sync and the list of changes from the posted json data
						print data
						cdata = json.loads(data)
						ts = cdata[0]
						del cdata[0]
						print "Received (last= " + str(ts) + "): " + str(cdata)

						# Add peer ID to all change items from client
						for item in cdata: item.append(peer);

						# Reduce the queue to just the most recent change for each key
						queue = g.queueMerge(cdata, ts)

						# Set the local data to the most recent values
						for item in queue: g.set(item[0],item[1])

						# Last sync was more than maxage seconds ago, send all data
						if app.timestamp() - ts > app.maxage: content = app.groups[group].json()

						# Otherwise send the queue of changes
						# - no timestamp is fine since just storing without merge on client
						else:

							# Get queue items that did not originate from this client and use only key and value
							cdata = []
							for item in filter(lambda f: f[3] != peer, queue): cdata.append([item[0], item[1]])
							content = json.dumps(cdata)
							if content != '[]': print "Sending to " + peer + ': ' + content

			# Serve the requested file if it exists and isn't a directory
			elif os.path.exists(path) and not os.path.isdir(path):
				h = open(path, "rb")
				content = h.read()
				h.close()
				ctype = mimetypes.guess_type(uri)[0]
				if ctype == None: ctype = 'text/plain'

			# Return a 404 for everything else
			else:
				status = "404 Not Found"
				content += "<html><head><title>404 Not Found</title></head>\n"
				content += "<body><h1>Not Found</h1>\n"
				content += "<p>The requested URL " + uri + " was not found on this server.</p>\n"
				content += "</body></html>"

			header = "HTTP/1.0 " + status + "\r\n"
			header += "Date: " + date + "\r\n"
			header += "Server: " + server + "\r\n"
			header += "Content-Type: " + ctype + "\r\n"
			header += "Connection: keep-alive\r\n"
			header += "Content-Length: " + str(len(content)) + "\r\n\r\n"

			self.send(header + content)

class server(asyncore.dispatcher):

	def __init__(self, a, host, port):
		global app
		app = a
		asyncore.dispatcher.__init__(self)
		self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
		self.set_reuse_addr()
		self.bind((host, port))
		self.listen(5)

	def handle_accept(self):
		pair = self.accept()
		if pair is not None:
			sock, addr = pair
			h = handler(sock)
