#!/usr/bin/python2.7
import __builtin__

__builtin__.constants = {}

def const(name, value):
	constants[name] = value
	setattr(__builtin__, name, value)

"""
Application-wide 'constants' which are also available to the client side
"""

# Array keys
const('INTERFACE', 1)
const('PEER', 2)
const('LOCAL', 2)
const('CHANGES', 4)
const('GROUP', 5)
const('DATA', 6)
const('HTTP', 7)
const('WELCOME', 8)
const('STATUS', 9)

# Connectivity states
const('NOTCONNECTED', 10)
const('CONNECTED', 11)
const('ERROR', 12)
const('UNKNOWN', 13)
