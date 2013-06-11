#!/bin/sh
openssl genrsa -out /etc/ssl/private/dovecot.pem 1024
openssl req -new -key /etc/ssl/private/dovecot.pem -out /tmp/csr
openssl x509 -in /tmp/csr -out /etc/ssl/certs/dovecot.pem -req -signkey /etc/ssl/private/dovecot.pem -days 999

