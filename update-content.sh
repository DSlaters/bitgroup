#!/bin/bash
cd /tmp
rm od-content.xml.gz
wget http://www.organicdesign.co.nz/files/od-content.xml.gz
php /var/www/domains/localhost/wiki/maintenance/importDump.php /tmp/od-content.xml.gz
