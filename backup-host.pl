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
# Last updated: 2012-09-30, 11:04
#
use POSIX;
use Cwd 'realpath';

# Ensure CWD is in the dir containing this script
chdir $1 if realpath($0) =~ m|^(.+)/|;

# Initial parameters
$dir   = '/backup';
$date  = strftime( '%Y-%m-%d', localtime );
$admin = 'admin@organicdesign.co.nz';
$rsa   = '-i /home/scp/.ssh/id_rsa';
$host  = `hostname`;  # name used to identify backup server
$disk  = '';          # disk to check free space on
$free  = 5;           # minimum GB free before email is sent to admin
$pass  = '';          # MySQL root password
@files = ();          # locations to include in weekly file backup
@excl  = ();          # locations to exclude in weekly file backup (all items in @conf will be included in here automatically)
@conf  = ();          # list of files that should be encrypted (with root MySQL password)
@scp   = ();          # list of servers to send backups to over SCP protocol

# Override parameters from local backup configuration file
require "./backup-host.conf";

# Function to send passed file to hosts listed in @scp
sub transfer {
	if( $#scp >= 0 ) {
		my $f = shift;
		for( @scp ) {
			print "\tSending $f to $_\n";
			qx( scp -l 1000 $rsa $dir/$f scp\@$_:/ );
		}
	}
}

# Backup and compress MySQL databases (7zip file locked with MySQL root password)
if( `which mysqldump` ) {
	print "Backing up databases\n";
	$s7z = "$host-$date.sql.7z";
	$sql = "$dir/$host-$date.sql";
	qx( mysqldump -u root --password='$pass' -A >$sql );
	qx( 7za a $dir/$s7z $sql -p$pass );
	qx( chown scp:scp $dir/$s7z );
	qx( chmod 600 $dir/$s7z );
	unlink $sql;
	transfer $s7z;
}

# Backup, compress and send files weekly
if( $date =~ /[0-9]+-[0-9]+-(01|08|16|24)/ ) {
	print "Doing weekly filesystem backup\n";

	# Add all @conf items to @excl since they contain sensitive information
	push @excl, $_ for @conf;

	# Make @conf into an exclusions file for tar
	$xf = "$dir/excl";
	qx( echo "" > $xf );
	qx( echo "$_" >> $xf ) for @excl;

	# Compress and encrypt the configs
	if( $#conf >= 0 ) {
		$f = join ' ', @conf;
		$conf = "$dir/$host-$date-conf.tar";
		qx( tar -cf $conf $f 2> /dev/null );
		qx( 7za a $conf.7z $conf -p$pass );
		qx( chown scp:scp $conf.7z );
		qx( chmod 600 $conf.7z );		
		unlink $conf;
	} else { $conf = '' }

	# Compress the main files
	$tgz = "$host-$date.tgz";
	$f = join ' ', @files;
	$f .= " $conf.7z" if $conf;
	qx( tar -czf $dir/$tgz $f -X $xf 2> /dev/null );
	qx( chown scp:scp $dir/$tgz );
	qx( chmod 600 $dir/$tgz );
	unlink "$conf.7z" if $conf;
	unlink $xf;
	transfer $tgz;
}

# Prune older files in the backup dir
print "Pruning old files\n";
opendir( DH, $dir ) or die $!;
while( my $f = readdir( DH ) ) {
	if( $f =~ m|[^/]+-(\d\d\d\d)-(\d\d)-(\d\d).[^/]+$| ) {
		$df = "$dir/$f";
		my $y = $1;
		my $m = $2;
		my $d = $3;
		my $u = mktime(0, 0, 0, $d, $m - 1, $y - 1900);
		$age = ( time() - $u ) / 86400;
		if( $age > 730 )    { unlink $df unless $d == 1 and $m == 1 }   # Older than 2 years
		elsif( $age > 365 ) { unlink $df unless $d == 1 }               # Older than 1 year
		elsif( $age > 90 )  { unlink $df unless $d =~ /(01|15)/ }       # Older than 3 months
		elsif( $age > 60 )  { unlink $df unless $d =~ /(01|07|15|27)/ } # Older than 2 months
		elsif( $age > 30 )  { unlink $df unless $d =~ /\d[13579]/ }     # Older than 1 month
		print "\t$f\n" unless -e $df;
	}
}
closedir( DH );

# Email admin if server is low on space
if( $disk ) {
	$df = qx( df $disk );
	$df =~ /\d.+?\d+.+?\d+.+?(\d+)/;
	$size = int($1/104857.6+0.5)/10;
	$msg = "There is $size\G of free space available on host \"$host\".";
	print "$msg\n";
	if( $size < $free ) {
		$tmp = "/tmp/free.txt";
		open FH,'>', $tmp;
		print FH $msg;
		close FH;
		qx( mail -s "Host \"$host\" is running low on disk space" $admin < $tmp );
		unlink $tmp;
	}
}
