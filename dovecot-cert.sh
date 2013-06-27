#!/bin/sh
openssl genrsa -out /var/www/ssl/dovecot.pem 1024
openssl req -new -key /var/www/ssl/dovecot.pem -out /tmp/csr
openssl x509 -in /tmp/csr -out /var/www/ssl/dovecot.pem -req -signkey /var/www/ssl/dovecot.pem -days 999
