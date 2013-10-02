#!/usr/bin/perl
for(glob "$ARGV[0]/Maildir/.Sent/cur/*") { rename $_, $_.'S' if /2,$/ }
