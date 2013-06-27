#!/bin/sh
openssl genrsa -out /etc/dovecot/private/dovecot.pem 1024
openssl req -new -key /etc/dovecot/private/dovecot.pem -out /tmp/csr
openssl x509 -in /tmp/csr -out /etc/dovecot/dovecot.pem -req -signkey /etc/dovecot/private/dovecot.pem -days 999

