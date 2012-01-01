#!/usr/bin/perl
# Organic Design server daily backup job called from crontab
use POSIX qw(strftime setsid);
require "/var/www/tools/wikid.conf";
require "/var/www/tools/wiki.pl";

$dir  = '/backup';
$date = strftime( '%Y-%m-%d', localtime );

# Wiki settings
$wiki = "https://organicdesign.co.nz/wiki/index.php";
wikiLogin( $::wiki, $wikiuser, $wikipass );

# Return size of passed file in MB
sub size { return (int([stat shift]->[7]/104857.6+0.5)/10).'MB'; }

# Post a comment to the wiki's server-log article
sub comment {
	$comment = shift;
	wikiAppend($::wiki, 'Server log', "\n*$comment", $comment);
}

# Backup and compress databases
if (1) {
	$s7z = "all-$date.sql.7z";
	$sql = "$dir/all.sql";
	qx( mysqldump -u $wgDBuser --password='$wgDBpassword' -A >$sql );
	qx( 7za a $dir/$s7z $sql );
	qx( chmod 644 $dir/$s7z );
	comment "DB backup: $s7z (".size($sql)."/".size("$dir/$s7z").")";
}

# Backup config files & svn repos
if (1) {
	$conf = join( ' ',
		"/var/www/tools/wikid.conf",
		"/var/www/tools/backup.pl",
        	"/etc/apache2/sites-available",
		"/etc/exim4",
		"/etc/bind9",
		"/var/cache/bind",
		"/etc/ssh/sshd_config",
		"/etc/samba/smb.conf",
		"/etc/crontab",
		"/etc/network/interfaces"
	);
	qx( tar -czf $dir/config-$date.tgz $conf );
	qx( svnadmin dump /svn/extensions > $dir/extensions-$date.svn );
	qx( svnadmin dump /svn/tools > $dir/tools-$date.svn );
}

# Users's DB backup
if (1) {
	qx( rm /home/aap/aap-*.sql.7z );
	$s7z = "/home/aap/aap-$date.sql.7z";
	$sql = "$dir/aap.sql";
	qx( mysqldump -u $wgDBuser --password='$wgDBpassword' aap >$sql );
	qx( 7za a $s7z $sql );
	qx( chown aap:aap $s7z );

}

# Tmp file to use for tar's before compressed
$tar = "$dir/tmp.tar";

# Backup and compress wiki/web structure
if ($date =~ /[0-9]+-[0-9]+-(01|09|16|24)/) {
	$t7z = "www-$date.t7z";
	qx( tar -cf $tar /var/www -X /var/www/tools/backup-exclusions );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "FS backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup and compress aap files structure
if ($date =~ /[0-9]+-[0-9]+-(02|10|17|25)/) {
	$t7z = "/home/aap/aap-files-$date.t7z";
	qx( tar -cf $tar /var/www/wikis/aap );
	qx( 7za a $t7z $tar );
	qx( chmod 644 $t7z );
	qx( chown aap:aap $t7z );
	comment "aap files backup: $t7z (".size($tar)."/".size($t7z).")";
}

# Backup and compress Nad's files
if ($date =~ /[0-9]+-[0-9]+-(07|14|21|28)/) {
	$t7z = "nad-server-$date.t7z";
	qx( tar -cf $tar /home/nad/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "Nad's backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup and compress Milan's files
if ($date =~ /[0-9]+-[0-9]+-(08|15|22|29)/) {
	$t7z = "milan-server-$date.t7z";
	qx( tar -cf $tar /home/milan/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "Milan's backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup and compress Zenia's files
if ($date =~ /[0-9]+-[0-9]+-(06|13|20|27)/) {
	$t7z = "zenia-server-$date.t7z";
	qx( tar -cf $tar /home/zenia/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "Zenia's backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup and compress Zenovia's files
if ($date =~ /[0-9]+-[0-9]+-(04|11|18|25)/) {
	$t7z = "zenovia-server-$date.t7z";
	qx( tar -cf $tar /home/zenovia/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "Zenovia's backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup and compress Jack's files
if ($date =~ /[0-9]+-[0-9]+-(04|11|18|25)/) {
	$t7z = "jack-server-$date.t7z";
	qx( tar -cf $tar /home/jack/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 644 $dir/$t7z );
	comment "Jack's backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Add a comment about number of spams and hams
$_ = `sa-learn --dump magic`;
comment m/\s([1-9]+\d*).+?am[\x00-\x1f]+.+?([1-9]+\d*).+?am[\x00-\x1f]+.+?([1-9]+\d*).+?ns$/m
	? "$1 spams and $2 hams have been processed with $3 tokens"
	: "ERROR";

# And add a comment about free space on the server
$df = qx( df -h /dev/sda3 );
$df =~ /\d.+?\d+.+?\d+.+?([0-9.]+)/;
comment "Note: there is only " . $1 . "G of free space available." if $1 < 25;


