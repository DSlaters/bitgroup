#!/usr/bin/perl
#
# Default OrganicDesign backup script
# - dumps and compresses all databases daily
# - copies and compresses config and www structure weekly
# - transfers all created files over FTP if details supplied
# - passwords and other details extracted from wikid.conf
#
use POSIX qw(strftime setsid);
use Net::FTP;
require "wikid.conf";

$dir  = '/backup';
$date = strftime( '%Y-%m-%d', localtime );
@ftpFiles = ();

# Return size of passed file in MB
sub size { return (int([stat shift]->[7]/104857.6+0.5)/10).'MB'; }

# Backup and compress databases
$s7z  = "$wgDBname-db-$date.sql.7z";
$sql  = "$dir/all.sql";
$lock = defined $wgDBnolock ? '--lock-tables=FALSE' : '';
qx( mysqldump -u $wgDBuser --password='$wgDBpassword' $lock -A >$sql );
qx( nice -n 19 7za a $dir/$s7z $sql );
qx( chmod 644 $dir/$s7z );
print "\n\nDB backup: $s7z (".size($sql)."/".size("$dir/$s7z").")\n";
qx( rm -f $sql );
push @ftpFiles, "$dir/$s7z";

# Backup config files
$conf = join( ' ',
	"/var/www/tools/wikid.conf",
	"/etc/apache2/sites-available",
	"/etc/exim4",
	"/etc/bind9",
	"/var/cache/bind",
	"/etc/ssh/sshd_config",
	"/etc/samba/smb.conf",
	"/etc/crontab",
	"/etc/network/interfaces"
);
$tgz = "$wgDBname-config-$date.tgz";
qx( tar -czf $dir/$tgz $conf );
print "\n\nConfig backup: $tgz (".size("$dir/$tgz").")\n";
push @ftpFiles, "$dir/$tgz";

# Backup and compress wiki/web structure
$t7z = "$wgDBname-www-$date.t7z";
$tmp = "$dir/tmp.tar";
qx( tar -cf $tmp /var/www -X ./backup-exclusions );
qx( nice -n 19 7za a $dir/$t7z $tmp );
qx( chmod 644 $dir/$t7z );
print "FS backup: $t7z (".size($tmp)."/".size("$dir/$t7z").")\n";
qx( rm -f $tmp );
push @ftpFiles, "$dir/$t7z";


# Transfer the files over FTP
if( defined $ftpHost ) {
	$ftp = Net::FTP->new( $ftpHost ) or die "Cannot connect to $ftpHost: $@";
	$ftp->login( $ftpUser, $ftpPass ) or die "Cannot login ", $ftp->message;
	$ftp->binary();
	$ftp->put( $_, $_ ) for @ftpFiles;
}
