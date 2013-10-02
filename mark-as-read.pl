#!/usr/bin/perl
sleep(0.5);
for(glob "/home/*/Maildir/.Sent/cur/*") { rename $_, $_.'S' if /2,$/ }
