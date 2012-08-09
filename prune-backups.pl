#!/usr/bin/perl
#
# Remove old backup files from passed directories
#
# Copyright (C) 2012 Aran Dunkley
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
use POSIX;
use strict;
use warnings;

for my $dir ( @ARGV ) {
	if( -d $dir ) {
		for my $f ( grep "*-(\d\d\d\d)-(\d\d)-(\d\d).*" ) {
			my $y = $1;
			my $m = $2;
			my $d = $3;

			# Get unix timestamp from file's date
			my $u = mktime(0, 0, 0, $d, $m, $y - 1900);

			# Age of the file in days
			$age = (localtime - $u) / 86400;

			# Older than 2 years
			if( $age > 730 ) {
				unlink $f unless $d == 1 and $m == 1;
			}

			# Older than 1 year
			elsif( $age > 365 ) {
				unlink $f unless $d == 1;
			}

			# Older than 3 months
			elsif( $age > 90 ) {
				unlink $f unless $d =~ /(01|15)/;
			}

			# Older than 2 months
			elsif( $age > 60 ) {
				unlink $f unless $d =~ /(01|07|15|27)/;
			}

			# Older than 1 month
			elsif( $age > 30 ) {
				unlink $f unless $d =~ /\d[13579]/;
			}
		}
	}
}


