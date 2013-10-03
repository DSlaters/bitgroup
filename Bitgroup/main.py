#!/usr/bin/python2.7
import __builtin__
import os, sys, ConfigParser

# Declare application-wide constants
__builtin__.CLIENTSOCK = 1
__builtin__.PEERSOCK = 2
__builtin__.PEERS = 3
__builtin__.CHANGES = 4
__builtin__.GROUP = 5
__builtin__.DATA = 6
__builtin__.BM_NOTCONNECTED = 0
__builtin__.BM_CONNECTED = 1
__builtin__.BM_ERROR = 2

# Read the configuration file
configfile = os.path.dirname(__file__) + '/.config'
config = ConfigParser.SafeConfigParser();
config.read(configfile)

# Get location of Bitmessage from config, same location is this if not defined
try:
	bmsrc = config.get('bitmessage', 'program')
except:
	bmsrc = os.path.dirname(os.path.dirname(__file__)) + '/PyBitmessage/src'
if os.path.exists(bmsrc):
	sys.path.append(bmsrc)
else:
	raise Exception("Error: Couldn't find Bitmessage src directory.")

import singleton
import asyncore
from app import *

if __name__ == '__main__':

	# Bail if this app is already running
	singleton.SingleInstance()

	# Instantiate the main app instance
	App(config, configfile)

	# Wait for incoming connections and handle them forever
	try:
		print "Press Ctrl+C to exit."
		asyncore.loop()
	except KeyboardInterrupt:
		print "Exiting..."
		pass
