#!/usr/bin/perl
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

# Get free space on main drive
$df = qx( df -h /dev/sda1 );
$df =~ /\d+.+?\d+.+?(\d+)/;
$free = $1;

# If less that 5GB free, delete oldest backups
if( $free < 5 ) {

	my $errfile = '/tmp/delbak.msg';
	my $subject = "Low space warning...";
	open FH,'>', $errfile;
	print FH "There is only " . $1 . "G of free space available on the OD server!";
	close FH;
	qx( mail -s "$subject" aran\@organicdesign.co.nz jack\@jack.co.nz < $errfile );
	qx( rm -f $errfile );

}
