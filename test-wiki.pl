#!/usr/bin/perl
# Organic Design server daily backup job called from crontab
use POSIX qw(strftime setsid);
require "/var/www/tools/wikid.conf";
require "/var/www/tools/wiki.pl";

# Wiki settings
$wiki = "https://organicdesign.co.nz/wiki/index.php";
wikiLogin( $::wiki, $wikiuser, $wikipass );


# Post a comment to the wiki's server-log article
sub comment {
	$comment = shift;
	wikiAppend($::wiki, 'Server log', "\n*$comment", $comment);
}

$df = qx( df /dev/sda3 );
$df =~ /\d.+?\d+.+?\d+.+?(\d+)/;
$size = int($1/104857.6+0.5)/10;
comment "There is $size\G of free space available.";


