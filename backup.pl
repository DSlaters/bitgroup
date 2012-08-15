#!/usr/bin/perl
# Organic Design server daily backup job called from crontab
use POSIX qw(strftime setsid);
require "/var/www/tools/wikid.conf";
require "/var/www/tools/wiki.pl";

$dir  = '/backup';
$tar = "$dir/tmp.tar";
$date = strftime( '%Y-%m-%d', localtime );

# Wiki settings
$wiki = "https://www.organicdesign.co.nz/wiki/index.php";
wikiLogin( $::wiki, $wikiuser, $wikipass );


# Return size of passed file in MB
sub size { return (int([stat shift]->[7]/104857.6+0.5)/10).'MB'; }

# Post a comment to the wiki's server-log article (overwrites since it has history anyway)
sub comment {
	my $comment = shift;
	wikiEdit( $::wiki, 'Server log', "$comment\n[[Category:Excluded from RecentActivity]]", $comment );
}

# Backup passed users Maildir
sub backupMail {
	my $name = shift;
	my $lcname = lc $name;
	my $t7z = "$lcname-server-$date.t7z";
	qx( tar -cf $tar /home/$lcname/Maildir );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 640 $dir/$t7z );
	comment "$name\'s backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
	qx( rm $tar );
}


# Backup and compress databases
$s7z = "all-$date.sql.7z";
$sql = "$dir/all.sql";
qx( mysqldump -u $wgDBuser --password='$wgDBpassword' --default-character-set=latin1 -A >$sql );
qx( 7za a $dir/$s7z $sql );
qx( chmod 640 $dir/$s7z );
comment "DB backup: $s7z (".size($sql)."/".size("$dir/$s7z").")";
qx( rm $sql );

# Backup Znazza database
$sql = "/var/www/domains/znazza/images/znazza-backup.sql";
qx( mysqldump -u $wgDBuser --password='$wgDBpassword' --default-character-set=latin1 znazza >$sql );

# Backup and compress wiki/web structure
if ($date =~ /[0-9]+-[0-9]+-(01|09|16|24)/) {
	$t7z = "www-$date.t7z";
	qx( tar -cf $tar /var/www -X /var/www/tools/backup-exclusions );
	qx( 7za a $dir/$t7z $tar );
	qx( chmod 640 $dir/$t7z );
	comment "FS backup: $t7z (".size($tar)."/".size("$dir/$t7z").")";
}

# Backup users Maildirs
backupMail('Nad')     if $date =~ /[0-9]+-[0-9]+-(07|14|21|28)/;
backupMail('Beth')    if $date =~ /[0-9]+-[0-9]+-(08|15|22|01)/;
backupMail('Milan')   if $date =~ /[0-9]+-[0-9]+-(09|16|23|02)/;
backupMail('Zenia')   if $date =~ /[0-9]+-[0-9]+-(10|17|24|03)/;
backupMail('Zenovia') if $date =~ /[0-9]+-[0-9]+-(11|18|25|04)/;
backupMail('Jack')    if $date =~ /[0-9]+-[0-9]+-(12|19|26|05)/;

# Backup and compress aap files structure
if ($date =~ /[0-9]+-[0-9]+-(02|10|17|25)/) {
	$t7z = "/home/aap/aap-files-$date.t7z";
	qx( tar -cf $tar /var/www/wikis/aap );
	qx( 7za a $t7z $tar );
	qx( chmod 600 $t7z );
	qx( chown aap:aap $t7z );
	comment "aap files backup: $t7z (".size($tar)."/".size($t7z).")";
}
qx( rm /home/aap/aap-*.sql.7z );
$s7z = "/home/aap/aap-$date.sql.7z";
$sql = "$dir/aap.sql";
qx( mysqldump -u $wgDBuser --password='$wgDBpassword' aap >$sql );
qx( 7za a $s7z $sql );
qx( chown aap:aap $s7z );

# Backup config files & svn repos
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
qx( svnadmin dump /svn/work > $dir/work-$date.svn );

# Add a comment about number of spams and hams
$_ = `sa-learn --dump magic`;
comment m/\s([1-9]+\d*).+?am[\x00-\x1f]+.+?([1-9]+\d*).+?am[\x00-\x1f]+.+?([1-9]+\d*).+?ns$/m
	? "$1 spams and $2 hams have been processed with $3 tokens"
	: "ERROR";

# And add a comment about free space on the server
$df = qx( df /dev/sda3 );
$df =~ /\d.+?\d+.+?\d+.+?(\d+)/;
$size = int($1/104857.6+0.5)/10;
comment "There is $size\G of free space available.";


