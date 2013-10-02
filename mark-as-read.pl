#!/usr/bin/perl
for(glob "/home/*/Maildir/.Sent/new/*") { rename $_, $_.':2,S' unless /:/ }
