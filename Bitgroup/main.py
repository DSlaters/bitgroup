#!/usr/bin/python2.7
import singleton
from app import *

if __name__ == '__main__':

	# Bail if this app is already running
	singleton.SingleInstance()

	# Instantiate the main app instance
	app = App()

	# Wait for incoming connections and handle them forever
	try:
		print "Press Ctrl+C to exit."
		asyncore.loop()
	except KeyboardInterrupt:
		print "Exiting..."
		print "Sockets might get stuck open..."
		print "Just wait a minute before restarting the program..."
		pass
