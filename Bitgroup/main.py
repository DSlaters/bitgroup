#!/usr/bin/python2.7
import os, sys, ConfigParser
import constants
import dev

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

	# Bail if this app is already running on this port
	singleton.SingleInstance(config.getint('interface', 'port'))

	# Instantiate the main app instance
	App(config, configfile)

	# Wait for incoming connections and handle them forever
	try:
		app.log("Press Ctrl+C to exit.")
		asyncore.loop()
	except KeyboardInterrupt:
		app.log("Exiting...")
		if app.dev: app.api.shutdown()
		pass
