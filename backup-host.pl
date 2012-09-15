#!/usr/bin/perl
#
# Daily backup job for Organic Design server network
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

# Ensure CWD is in the dir containing this script
chdir $1 if realpath($0) =~ m|^(.+)/|;

# Initial parameters
$dir   = '/home/scp';
$date  = strftime( '%Y-%m-%d', localtime );
$admin = 'admin@organicdesign.co.nz';
$rsa   = '-i /home/scp/.ssh/id_rsa';
$host  = `hostname`;  # name used to identify backup server
$disk  = '';          # disk to check free space on
$free  = 5;           # minimum GB free before email is sent to admin
$pass  = '';          # MySQL root password
$files = ();          # locations to include in weekly file backup (also add exclusions list to backup.excl)
$conf  = ()           # list of files that should be encrypted (with root MySQL password)
$scp   = ();          # list of servers to send backups to over SCP protocol

# Override parameters from local backup configuration file
require "./backup-host.conf";

# Backup and compress MySQL databases (7zip file locked with MySQL root password)
if( qx( which mysqldump ) ) {
	$s7z = "$host-$date.sql.7z";
	$sql = "$dir/tmp.sql";
	qx( mysqldump -u root --password='$pass' -A >$sql );
	qx( 7za a $dir/$s7z $sql -p$pass );
	qx( chown scp:scp $dir/$s7z );
	qx( chmod 600 $dir/$s7z );
	unlink $sql;
}

# If there's SCP info, send the backup to the target servers
if( $#scp >= 0 ) { qx( scp $rsa $dir/$s7z scp\@$_:$dir ) for @scp }

# Backup, compress and send files weekly
if( $date =~ /[0-9]+-[0-9]+-(01|08|16|24)/ ) {

	# Compress and encrypt the configs
	if( $#conf >= 0 ) {
		qx( 7za a $dir/$s7z $sql -p$pass );
		qx( chown scp:scp $dir/$s7z );
		qx( chmod 600 $dir/$s7z );		
	} else { $conf = '' }

	# Compress the main files
	$tgz = "$dir/$host-$date.tgz";
	$f = join ' ', $files;
	$f .= " $conf" if $conf;
	$x = -e "./backup-host.excl" ? "-X ./backup-host.excl" : "";
	qx( tar -czf $tgz $f $x );
	qx( chown scp:scp $dir/$tgz );
	qx( chmod 600 $dir/$tgz );
	if( $#scp >= 0 ) { qx( scp $rsa $dir/$tgz scp\@$_:$dir ) for @scp }
}

# Prune older files in the backup dir
opendir( DH, $dir ) or die $!;
while( my $f = readdir( DH ) ) {
	if( $f =~ m|[^/]+-(\d\d\d\d)-(\d\d)-(\d\d).[^/]+$| ) {
		$f = "$dir/$f";
		my $y = $1;
		my $m = $2;
		my $d = $3;
		my $u = mktime(0, 0, 0, $d, $m - 1, $y - 1900);
		$age = ( time() - $u ) / 86400;
		if( $age > 730 )    { unlink $f unless $d == 1 and $m == 1 }   # Older than 2 years
		elsif( $age > 365 ) { unlink $f unless $d == 1 }               # Older than 1 year
		elsif( $age > 90 )  { unlink $f unless $d =~ /(01|15)/ }       # Older than 3 months
		elsif( $age > 60 )  { unlink $f unless $d =~ /(01|07|15|27)/ } # Older than 2 months
		elsif( $age > 30 )  { unlink $f unless $d =~ /\d[13579]/ }     # Older than 1 month
	}
}
closedir( DH );

# Email admin if server is low on space
if( $disk ) {
	$df = qx( df $disk );
	$df =~ /\d.+?\d+.+?\d+.+?(\d+)/;
	$size = int($1/104857.6+0.5)/10;
	if( $size < $free ) {
		$tmp = "/tmp/free.txt";
		open FH,'>', $tmp;
		print FH "There is $size\G of free space available on $host.";
		close FH;
		qx( mail -s "$host is running low on disk space" $admin < $tmp );
		unlink $tmp;
	}
}
