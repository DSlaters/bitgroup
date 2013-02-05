#!/usr/bin/perl
#
# This script is a Perl version of the MediaWiki deleteOldRevisions maintenance script
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
use DBI;

die "\nDelete old revisions from a MediaWiki

Usage:
	deleteOldRevisions.pl db.prefix config

Notes:
- config is the file that contains $wgDBuser and $wgDBpassword
" if $#ARGV != 1;

require( $ARGV[1] );
$ARGV[0] =~ /^(\w+)\.(\w*)$/;
( $db, $prefix ) = ( $1, $2 );



### Initialise the DB ###

$dbh = DBI->connect( "dbi:mysql:$db", $wgDBuser, $wgDBpassword )
	or die "\nCan't connect to database '$db': ", $DBI::errstr, "\n";

sub tableName { return '`' . $prefix . shift . '`' }
$tbl_pag = tableName( 'page' );
$tbl_rev = tableName( 'revision' );
$tbl_arc = tableName( 'archive' );
$tbl_txt = tableName( 'text' );

sub query {
	$sql = shift;
	$sth = $dbh->prepare( $sql );
	$sth->execute() or die "\nCould not execute sql \"$sql\"\n", $DBI::errstr, ")\n\n";
	return $sth;
}



### Delete the revisions ###

# Get "active" revisions from the page table
print "Searching for active revisions...\n";
$res = query( "SELECT page_latest FROM $tbl_pag" );
@cur = ();
push @cur, $data[0] while @data = $res->fetchrow_array();
print "done.\n";

# Delete all revisions that aren't in this set
print "Deleting inactive revisions...\n";
$set = join ', ', @cur;
query( "DELETE FROM $tbl_rev WHERE rev_id NOT IN ( $set )" );
print "done.\n";



### Purge redundant text records ###

# Get "active" text records from the revisions table
print "Searching for active text records in revisions table...\n";
$res = query( "SELECT DISTINCT rev_text_id FROM $tbl_rev" );
@cur = ();
push @cur, $data[0] while @data = $res->fetchrow_array();
print "done.\n";

# Get "active" text records from the archive table
print "Searching for active text records in archive table...\n";
$res = query( "SELECT DISTINCT ar_text_id FROM $tbl_arc" );
push @cur, $data[0] while @data = $res->fetchrow_array();
print "done.\n";

# Delete all text records not in these sets
print "Deleting inactive text records...\n";
$set = join ', ', @cur;
query( "DELETE FROM $tbl_txt WHERE old_id NOT IN ( $set )" );
print "done.\n";
