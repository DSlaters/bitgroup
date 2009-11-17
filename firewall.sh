#!/bin/sh

EXT = "eth0"
INT = "eth1"
 
# delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
 
# Always accept loopback traffic
iptables -A INPUT -i lo -j ACCEPT
 
# Allow established connections, and those not coming from the outside
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state NEW -i ! $EXT -j ACCEPT
iptables -A FORWARD -i $EXT -o $INT -m state --state ESTABLISHED,RELATED -j ACCEPT
 
# Allow outgoing connections from the LAN side.
iptables -A FORWARD -i $INT -o $EXT -j ACCEPT
 
# Masquerade.
iptables -t nat -A POSTROUTING -o $EXT -j MASQUERADE
 
# Dont forward from the outside to the inside.
iptables -A FORWARD -i $INT -o $EXT -j REJECT
 
# Example pinhole: forward packets on port 5900 to 192.168.1.100
iptables -A FORWARD -i $EXT -o $INT -p tcp --dport 5900 -j ACCEPT
iptables -A PREROUTING -t nat -p tcp --dport 5900 -j DNAT --to-destination 192.168.1.100
 
# Enable routing.
echo 1 > /proc/sys/net/ipv4/ip_forward
