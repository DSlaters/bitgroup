#!/usr/bin/perl
use POSIX qw(strftime setsid);
require "/var/www/tools/wikid.conf";

$dir  = '/backup';
$date = strftime( '%Y-%m-%d', localtime );

# Return size of passed file in MB
sub size { return (int([stat shift]->[7]/104857.6+0.5)/10).'MB'; }

# Backup and compress databases
$s7z = "$wgDBname-db-$date.sql.7z";
$sql = "$dir/all.sql";
qx( mysqldump -u $wgDBuser --password='$wgDBpassword' -A >$sql );
qx( 7za a $dir/$s7z $sql );
qx( chmod 644 $dir/$s7z );
print "\n\nDB backup: $s7z (".size($sql)."/".size("$dir/$s7z").")\n";
qx( rm $sql );

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

# Backup and compress wiki/web structure
$t7z = "$wgDBname-www-$date.t7z";
$tmp = "$dir/tmp.tar";
qx( tar -cf $tmp /var/www -X /var/www/tools/backup-exclusions );
qx( 7za a $dir/$t7z $tmp );
qx( chmod 644 $dir/$t7z );
print "FS backup: $t7z (".size($tmp)."/".size("$dir/$t7z").")\n";
qx( rm $tmp );

