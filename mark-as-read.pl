#!/usr/bin/perl
for(glob "/home/$ARGV[0]/Maildir/.Sent/cur/*") { rename $_, $_.'S' if /2,$/ }
