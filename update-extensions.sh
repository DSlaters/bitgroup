#!/bin/bash
cd /tmp
rm od-extensions.tgz
wget http://www.organicdesign.co.nz/files/od-extensions.tgz
tar -zxf od-extensions.tgz
mkdir /var/www/extensions
cd /var/www/extensions
cp -ru /tmp/var/www/od-extensions/* ./
chown -R www-data:www-data ./
chmod -R 755 ./
