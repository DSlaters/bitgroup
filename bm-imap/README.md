bm-imap
=======

Bitmessage is a peer-to-peer communications protocol based on the Bitcoin crypto-currency used to send encrypted messages to another person or to many subscribers. It is decentralized and trustless, meaning that you need-not inherently trust any entities like root certificate authorities. It uses strong authentication which means that the sender of a message cannot be spoofed, and it aims to hide "non-content" data, like the sender and receiver of messages, from passive eavesdroppers like those running warrantless wiretapping programs. If Bitmessage is completely new to you, you may wish to start by reading the whitepaper at https://bitmessage.org/bitmessage.pdf

bmwrapper is a python script to let a local email client and PyBitmessage communicate, similar to AyrA's (generally much better) application: ﻿Bitmessage2Mail. It works by starting local SMTP and POP servers as an interface to the Bitmessage API.

bm-imap is used to utilise the functionality of bmwrapper on hosts that already have a running mail server and don't need an additional
SMTP and POP server running.

Incoming Bitmessage messages are now sent to a local email address, actually any email address would do, but if it's not local, then the security of using Bitmessage would be compromised. The email address that correspond to each Bitmessage address are added to a new "emailaddresses" section in the keys.dat configuration file in the form foo@bar.baz = BM-xxxxxxx. If an incoming Bitmessage's address does not match any of the email addresses then the first is used as a "catch all".

Outgoing messages are sent to a local user account that is configured to forward the message to Bitmessage. For example using Exim a filter can be set up in the local user's .forward file that uses the pipe command to send the message to this script for forwarding to Bitmessage. This user account is also the user under which Bitmessage should be running, and all them (PyBitmessage, PyBitmessage-Daemon, bmwrapper and bm-imap) should be located in this account's home directory.
