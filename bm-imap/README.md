bm-imap (based on bmwrapper from http://github.com/Arceliar/bmwrapper)
======================================================================

The original script is used to run local POP and SMTP servers as an interface for Bitmessage so that users can send and receive messages
with their Bitmessage address using their preferred email client.

I've adapted the code for running on a server that's already running a mail server to integrate with, so the POP and SMTP parts have been
removed.

Incoming messages are now sent to a local email address, actually any email address would do, but if it's not local, then the security of
using Bitmessage would be compromised.

Outgoing messages are sent to a local user account that is configured to forward the message to Bitmessage. For example using Exim a filter
can be set up in the local user's .forward file that uses the pipe command to send the message to this script for forwarding to Bitmessage.
This uses the same function that the bmwrapper SMTP server used, but is now called in response to the pipe command instead.

