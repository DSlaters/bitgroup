#!/usr/bin/python2.7
import __builtin__

__builtin__.constants = {}

def const(name, value):
	constants[name] = value
	setattr(__builtin__, name, value)

"""
Application-wide 'constants' which are also available to the client side
"""

# Connection types
const('CLIENTSOCK', 1)
const('PEERSOCK', 2)

# Common data-structure keys
const('PEERS', 3)
const('CHANGES', 4)
const('GROUP', 5)
const('DATA', 6)

# Bitmessage states
const('BM_NOTCONNECTED', 0)
const('BM_CONNECTED', 1)
const('BM_ERROR', 2)
