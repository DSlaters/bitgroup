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
			url = match.group(1)
			host = match.group(2)
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			server = app.name + "-" + app.version
			status = "200 OK"
			ctype = "text/html"
			content = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
			group = 'Foo'
			uri = os.path.abspath(url)
			path = app.docroot + uri

			# Serve the main HTML document if its a root request
			if uri == '/':
				content += "<title>" + group + " - " + app.name + "</title>\n"
				content += "<meta charset=\"UTF-8\" />\n"
				content += "<meta name=\"generator\" content=\"" + server + "\" />\n"
				content += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
				content += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
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

			http = "HTTP/1.0 " + status + "\r\n"
			http += "Date: " + date + "\r\n"
			http += "Server: " + server + "\r\n"
			http += "Content-Type: " + ctype + "\r\n"
			http += "Connection: close\r\n"
			http += "Content-Length: " + str(len(content)) + "\r\n\r\n"

			self.send(http + content)

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
