#!/usr/bin/perl
#
# Copyright (C) 2010 Aran Dunkley
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
# - Author: http://www.organicdesign.co.nz/nad
# - Started: 2010-12-06
#
# FS structure
#
# /var/www/domains
# /var/www/applications
# /var/www/instances
#
use DBI;
use Digest::MD5 qw( md5_hex );
use File::Temp qw( tempfile );
require( '/var/www/tools/wikid.conf' );

# Display usage info and die if too few or no parameters supplied
die "\nReplicate a mediawiki SQL database dump to many databases and prefixes.

Usage:
	appctl [--add|--remove] --id=instance-name --type=codebase-name --db=DBname --sql=/path/to/db.sql --domain=foo.baz

Notes:
- The database dump being used as a template must use a table prefix
- It should not include create or drop database statements.
- The destination tables will be replaced if they exist
" unless $#ARGV > 0 and $ARGV[1] =~ /^\w+\.\w+$/;

# TODO - get command line options

# Remove an instance
if( --remove ) {
	
	# Backup
	
	# Remove
	
}

# Add a new instance
if( --add ) {
	# Prepare a tmp file to store the adjusted dump in
	( $th, $tmp ) = tempfile();

	# Read in the template file to $sql
	open FH, '<', $template or die "\nCould not read template file '$template'\n";
	sysread FH, $sql, -s $template;
	close FH;

	# Sanity check on the db dump
	if( $type =~ /mediawiki/i ) {
		die "The SQL dump is not a valid MediaWiki!" unless $sql =~ /^CREATE TABLE `\w+_recentchanges/;
	}

	# Find the prefix being used and replace with new one
	die "Couldn't establish prefix!" unless $sql =~ /^CREATE TABLE `(\w+)_/m;
	$prefix = $1;
	$sql =~ s/`$prefix/`$pre/g;

	# Make a duplicate of the template modified to the current prefix
	$data = $sql;

	# Write the duplicate into a tmp file
	unlink $tmp;
	open FH, '>', $tmp or die "Could not open '$tmp' for writing";
	print FH $data or die "Could not write data for wiki $db.$pre to '$tmp'\n";
	close FH;

	# Pipe the file into MySQL and remove the tmp file
	qx( mysql -u $wgDBuser --password='$wgDBpassword' $db < $tmp );
	print "$type instance \"$id\" created successfully.\n";

	if( $type =~ /mediawiki/i ) {
		# add /var/www/instances subdir wiki symlink to codebase and files dir
		die "Instance directory \"$id\" already exists!" if -e "/var/www/instances/$id";
		
		
		# add symlink to /var/www/domains pointing to /var/www/instances
		qx( ln -s /var/www/instances/$id /var/www/domains/$domain );
		
		# add a LocalSettings.php to /var/www/instances
	}

}

