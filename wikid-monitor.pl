#!/usr/bin/perl
#
# wikid-monitor.pl - A cronjob for notifying about problems with the local wiki daemon (wikid.pl)
#
# - See http://www.organicdesign.co.nz/wikid
#
#
# Copyright (C) 2011 Aran Dunkley and others.
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
use Mail::Sendmail;
require( '/var/www/tools/wikid.conf' );

if( qx( ps ax | grep wiki[d] ) ) {

	qx( rm /var/www/tools/wikid.stopped );

} else {

	$msg = "The wiki daemon ($name) running on $domain has stopped! following is the last ten lines of the log\n\n"
	$msg .= qx( tail -n 10 /var/www/tools/wikif.log );

	sendmail(
		From    => "$name <" . ( lc $name ) . "@$domain>",
		To      => "aran@organicdesign.co.nz",
		Subject => "$name has stopped running!",
		Message => $msg,
	);

	qx( echo 1 > /var/www/tools/wikid.stopped );
}
