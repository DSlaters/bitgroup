# This will be a simple HHTP server to handle requests from the interface (and only the interface)
# it must populate and server the html templates and serve the JS, CSS and image resources
import socket
import asyncore
import time

class handler(asyncore.dispatcher_with_send):

    def handle_read(self):
		data = self.recv(8192)
		if data:
			date = time.strftime("%a, %d %b %Y %H:%M:%S %Z")
			self.send("HTTP/1.0 200 OK\r\nDate: " + date + "\r\nServer: Bitgroup\r\nContent-Type: text/html\r\nConnection: close\r\nContent-Length: 6\r\n\r\nHello!")

class server(asyncore.dispatcher):

	def __init__(self, host, port):
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
