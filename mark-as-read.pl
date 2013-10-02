#!/usr/bin/perl
for(glob "/home/*/Maildir/.Sent/cur/*") { rename $_, $_.'S' if /2,$/ }
