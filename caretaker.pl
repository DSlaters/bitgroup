#!/usr/bin/perl
#
# caretaker.pl - Organic Design wiki caretaker script
#
# Copyright (C) 2007-2010 Aran Dunkley and others.
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
require "wiki.pl";
require "wikid.conf";

# DB settings
$dbname = 'od';
$dbpfix = '';
$dbuser = wikiGetConfig( 'wgDBuser' );
$dbpass = wikiGetConfig( 'wgDBpass' );

# Login to wiki
wikiLogin( $wiki, $name, $wikipass );
my %ns = wikiGetNamespaces( $wiki );

# Connect to DB
my $dbh = DBI->connect( 'DBI:mysql:'.$dbname, lc $dbuser, $dbpass ) or die DBI->errstr;

# get a list of all titles in a category
my @list = ();
my $sth = $dbh->prepare( 'SELECT cl_from FROM ' . $dbpfix . 'categorylinks WHERE cl_to = "PERL"' );
$sth->execute();
push @list, @row[0] while @row = $sth->fetchrow_array;
$sth->finish;

# Uncomment this to loop through all articles in the wiki
#my $sth = $dbh->prepare( 'SELECT page_id FROM '.$::dbpfix.'page WHERE page_title = "Zhconversiontable"' );
#$sth->execute();
#my @row = $sth->fetchrow_array;
#$sth->finish;
#my $first = $row[0]+1;
#my $sth = $dbh->prepare( 'SELECT page_id FROM '.$::dbpfix.'page ORDER BY page_id DESC' );
#$sth->execute();
#@row = $sth->fetchrow_array;
#$sth->finish;
#my $last = $row[0];
#@list = ( $first .. $last );

# Loop through all articles one per second
my $sthid = $dbh->prepare( 'SELECT page_namespace,page_title,page_is_redirect FROM ' . $dbpfix . 'page WHERE page_id=?' );
my $done = 'none';
for ( @list ) {
	$sthid->execute( $_ );
	@row = $sthid->fetchrow_array;
	my @comments = ();
	my $title = $ns{$row[0]} ? $ns{$row[0]}.':'.$row[1] : $row[1];
	if ( $title && ( $row[2] == 0 ) ) {
		print "$title\n";

		# Read the article content
		$text = wikiRawPage( $wiki, $title );
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
		my $backup = $text;

		# ------ REPLACEMENT RULES --------------------------------------------------------------- #

		# Example rule: changing some record parameter names
		my $changes
			= $text =~ s/^\|\s*Foo\s*=/\| Bar =/gm
			+ $text =~ s/^\|\s*Baz\s*=/\| Biz =/gm
			+ $text =~ s/^\|\s*Buz\s*=/\| Boz =/gm;
			
		push @comments, $changes . ( $changes == 1 ? ' parameter' : ' parameters' ) . " renamed" if $changes;

		# ---------------------------------------------------------------------------------------- #

		# If article changed, write and comment
		$text =~ s/^\s+//;
		$text =~ s/\s+$//;
		if ( $text ne $backup ) {
			wikiEdit( $wiki, $title, $text, join( ', ', @comments ), 1 );
			$done = $done + 1;
			}
		}
	sleep( 0.2 );
	}

$sthid->finish;
$dbh->disconnect;
