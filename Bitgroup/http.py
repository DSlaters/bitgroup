# This will be a simple HHTP server to handle requests from the interface (and only the interface)
# it must populate and server the html templates and serve the JS, CSS and image resources
import socket
import asyncore
import time

class handler(asyncore.dispatcher_with_send):

	def handle_read(self):
		global app
		data = self.recv(8192)
		if data:
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			server = app.name + "-" + app.version
			group = 'Foo'

			html = "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
			html += "<title>" + group + " - " + app.name + "</title>\n"
			html += "<meta charset=\"UTF-8\" />\n"
			html += "<meta name=\"generator\" content=\"" + server + "\" />\n"
			html += "<script type=\"text/javascript\" src=\"/resources/jquery-1.10.2.min.js\"></script>\n"
			html += "<script type=\"text/javascript\" src=\"/main.js\"></script>\n"
			html += "</head>\n<body>\nHello world!\n</body>\n</html>\n"

			http = "HTTP/1.0 200 OK\r\n"
			http += "Date: " + date + "\r\n"
			http += "Server: " + server + "\r\n"
			http += "Content-Type: text/html\r\n"
			http += "Connection: close\r\n"
			http += "Content-Length: " + str(len(html)) + "\r\n\r\n"

			self.send(http + html)

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
