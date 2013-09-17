# This will be a simple HHTP server to handle requests from the interface (and only the interface)
# it must populate and server the html templates and serve the JS, CSS and image resources
import os
import socket
import asyncore
import time
import re
import mimetypes
import json
import struct
import urllib

syncTimes = {} # record of the last time each client connected

class handler(asyncore.dispatcher_with_send):

	def handle_read(self):
		global app
		data = self.recv(8192)
		match = re.match(r'^(GET|POST) (.+?)(\?.+?)? HTTP.+Host: (.+?)\s(.+?)\r\n\r\n\s*(.*?)\s*$', data, re.S)
		if data and match:
			method = match.group(1)
			uri = urllib.unquote(match.group(2)).decode('utf8') 
			host = match.group(4)
			head = match.group(5)
			data = match.group(6)
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			now  = app.timestamp()
			server = app.name + "-" + app.version
			status = "200 OK"
			ctype = "text/html"
			content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
			docroot = app.docroot

			# Identify the client stream using a unique ID in the header
			# TODO: There must be a proper way to identify client streams in Python
			match = re.search(r'X-Bitgroup-ID: (.+?)\s', head)
			client = match.group(1) if match else ''

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
				extsrc = ['/overview.js','/newgroup.js']
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
				content += "</script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
				content += "<link rel=\"stylesheet\" href=\"/resources/jquery-ui-1.10.3/themes/base/jquery-ui.css\" />\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-ui-1.10.3/ui/jquery-ui.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery.observehashchange.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/math.uuid.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/i18n.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
				content += extensions
				content += "</head>\n<body>\n</body>\n</html>\n"

			# If this is a for _sync.json merge the local and client change queues and return the changes
			elif base == '_sync.json':
				if group in app.groups:
					ctype = mimetypes.guess_type(base)[0]
					cdata = []
					g = app.groups[group]

					# Get the timestamp of the last time this client connected and update
					if client in syncTimes: ts = syncTimes[client]
					else: ts = 0
					syncTimes[client] = now

					# If the client sent change-data merge into the local data
					if data:
						cdata = json.loads(data)
						for item in cdata: g.set(item[0], item[1], item[2], client)
						print "Received from " + client + " (last=" + str(ts) + "): " + str(cdata)

					# Last sync was more than maxage seconds ago, send all data
					if now - ts > app.maxage: content = app.groups[group].json()

					# Otherwise send the queue of changes that have occurred since the client's last sync request
					else:
						content = g.changesForClient(client, ts - (now-ts)) # TODO: messy doubling of period (bug#3)
						if len(content) > 0: print "Sending to " + client + ': ' + json.dumps(content)

						# Put an object on the end of the list containing the application state data
						content.append(app.getStateData())

						# Convert the content to JSON ready for sending to the client
						content = json.dumps(content)

				else: content = json.dumps([app.getStateData()])

			# Serve the requested file if it exists and isn't a directory
			elif os.path.exists(path) and not os.path.isdir(path):
				ctype = mimetypes.guess_type(uri)[0]
				if ctype == None: ctype = 'text/plain'
				header = "HTTP/1.0 " + status + "\r\n"
				header += "Date: " + date + "\r\n"
				header += "Server: " + server + "\r\n"
				header += "Content-Type: " + ctype + "\r\n"
				header += "Connection: keep-alive\r\n"
				header += "Content-Length: " + str(os.path.getsize(path)) + "\r\n\r\n"
				self.send(header)
				try: self.send(open(path, "rb").read())
				except: print uri
				return

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
