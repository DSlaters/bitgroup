#!/usr/bin/perl
#
# Copyright (C) 2008-2012 Aran Dunkley
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
# http://www.gnu.org/copyleft/gpl.html
#
use POSIX qw(strftime setsid);

$wiki = $ARGV[0];
$scp = $ARGV[1];
$date = strftime( '%Y-%m-%d', localtime );

# Extract wiki database settings from LocalSettings.php
open LOCALSETTINGS, '<', "$wiki/LocalSettings.php";
while( <LOCALSETTINGS> ) {
	$wgDBname = $1 if /\$wgDBname\s*=\s*['"](.+?)["']/;
	$wgDBuser = $1 if /\$wgDBuser\s*=\s*['"](.+?)["']/;
	$wgDBpass = $1 if /\$wgDBpassword\s*=\s*['"](.+?)["']/;
}

# Create a tar of the image hash structure (no tmp, thumbs etc)
$tar = "/tmp/$wgDBname-$date.tar";
qx( tar -cf $tar $wiki/images/? );

# Dump the database and add it to the tar and comrpess it
$sql = "/tmp/$wgDBname.sql";
qx( mysqldump -u $wgDBuser --password='$wgDBpass' -A > $sql );
qx( tar -r -f $tar $sql );
qx( 7za a $tar.7z $tar );
qx( rm $sql $tar );


# If SCP info was supplied, send the backup off site and remove local files
if( $scp ) {
	qx( scp $tar.7z $scp );
	qx( rm $tar );
}
