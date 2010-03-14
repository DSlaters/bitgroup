#!/bin/bash
cd /tmp
rm od-tools.tgz
wget http://www.organicdesign.co.nz/files/od-tools.tgz
tar -zxf od-tools.tgz
cd /var/www/tools        
cp -ru /tmp/var/www/tools/* ./

