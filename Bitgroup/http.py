# This will be a simple HHTP server to handle requests from the interface (and only the interface)
# it must populate and server the html templates and serve the JS, CSS and image resources
import os
import socket
import asyncore
import time
import re
import mimetypes

class handler(asyncore.dispatcher_with_send):

	def handle_read(self):
		global app
		data = self.recv(8192)
		if data:
			match = re.match(r'^GET (.+?) HTTP.+Host: (.+?)\s', data, re.S)
			uri = match.group(1)
			host = match.group(2)
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			server = app.name + "-" + app.version
			status = "200 OK"
			ctype = "text/html"
			content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
			docroot = app.docroot

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
			if uri == '/':
				content += "<title>" + ( group + " - " if group else '' ) + app.name + "</title>\n"
				content += "<meta charset=\"UTF-8\" />\n"
				content += "<meta name=\"generator\" content=\"" + server + "\" />\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-ui-1.10.3/ui/jquery-ui.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery.observehashchange.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
				content += "<script type=\"text/javascript\">window.app.group = '" + group + "'</script>\n"
				content += "</head>\n<body>\nHello world!\n</body>\n</html>\n"

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
			header += "Connection: close\r\n"
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
			print 'Incoming connection from %s' % repr(addr)
			h = handler(sock)
