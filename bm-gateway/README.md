bm-gateway
==========

Bitmessage is a peer-to-peer communications protocol based on the Bitcoin crypto-currency used to send encrypted messages to another person or to many subscribers. It is decentralized and trustless, meaning that you need-not inherently trust any entities like root certificate authorities. It uses strong authentication which means that the sender of a message cannot be spoofed, and it aims to hide "non-content" data, like the sender and receiver of messages, from passive eavesdroppers like those running warrantless wiretapping programs. If Bitmessage is completely new to you, you may wish to start by reading the whitepaper at https://bitmessage.org/bitmessage.pdf

bmwrapper is a python script to let a local email client and PyBitmessage communicate, similar to AyrA's (generally much better) application, ﻿Bitmessage2Mail, but that's Windows-only. It works by starting local SMTP and POP servers as an interface to the Bitmessage API.

bm-gateway is utilises the functionality of bmwrapper on hosts that already have a running mail server and acts as a gateway between the local Bitmessage instance and the mail server without starting up an additional SMTP and POP server.

Incoming Bitmessage messages are now sent to a local email address, actually any email address would do, but if it's not local, then the security of using Bitmessage would be compromised. The email address that correspond to each Bitmessage address are added to a new "emailaddresses" section in the keys.dat configuration file in the form foo@bar.baz = BM-xxxxxxx. If an incoming Bitmessage's address does not match any of the email addresses then the second is used as a "catch all" (the first email address is the address of the user
account for outgoing messages, described below).

Outgoing messages are sent to a local user account that is configured to forward the messages to Bitmessage. The email address of this account is the first one in the "emailaddresses" section of the configuration and has no associated Bitmessage address. For example using Exim a filter can be set up in the local user's .forward file that uses the pipe command to send the message to this script for forwarding to Bitmessage. This user account is also the user under which Bitmessage should be running, and all them (PyBitmessage, PyBitmessage-Daemon, bmwrapper and bm-gateway) should be located in this account's home directory.

Installation
============
First set up an unprivileged user account to run Bitmessage and all the scripts under. Install Bitmessage, Bitmessage-Daemon, bmwrapper and bm-gateway into this user's home directory. Add a .config/PyBitmessage/keys.dat configuration file for Bitmessage with the API enabled and add a new "emailaddresses" section with mappings of each of your email addresses to Bitmessage addresses, including the address of the account through which all outgoing messages will be sent, e.g.

[emailaddresses]
bitmessage@foo.com =
bar@foo.com = BM-2D8WUhjPbRABrRdZqQeYZUAJdpvxDfjej4
baz@foo.com = BM-2D7F9ILxyeVXqrMsfyRcPZuhzhDXjMtkbQ

Set up an email account for this user which will be the generic account through which all outgoing Bitmessage messages will sent, in the example configuration above, this email address is assumed to be "bitmessage@foo.com". You'll need to set up a way for the emails to be sent to the bm-imap/imap-out.py script instead of to standard delivery. For Exim this can be done by using a filter in a .forward file in the user's home directory that uses the pipe command. Here's an example filter which uses a condition to check that it's a Bitmessage recipient incase the user also has normal mail delivered too.

# Exim filter
if
   $header_to matches "^BM-"
then
   pipe "$home/bm-gateway/out.py"
endif

The ''bm-gateway/in.py'' script will need to be called on a regular basis to check for new incoming Bitmessage messages and forward them to the appropriate local email account. You can add something similar to the following to your ''crontab'' to achieve this:

*/5 * * * * bitmessage /home/bitmessage/bm-imap/imap-in.py > /dev/null

Usage
=====
Nothing needs to be done to receive or reply to messages, they just arrive in the inbox and can be replied to in to in the normal way. Sending messages to Bitmessage addresses that isn't a reply is done by using the following format for the To field:
BM-2D7F9ILxyeABCD1234xyzfPZuhzhD <bitmessage@foo.com>
where the name portion is the recipient Bitmessage address, and the email address portion is the address of the account that was set up to receive all the messages for the gateway to forward to Bitmessage - in our example above, bitmessage@foo.com
