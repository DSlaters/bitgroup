#!/bin/bash
cd /tmp
rm od-extensions.tgz
wget http://www.organicdesign.co.nz/files/od-extensions.tgz
tar -zxf od-extensions.tgz
cp -ru var/www/od-extensions /var/www/extensions
cd /var/www/extensions
chown -R www-data:www-data ./
chmod -R 755 ./
