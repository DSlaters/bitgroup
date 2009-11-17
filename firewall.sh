#!/bin/sh

# delete all existing rules.
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Always accept loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections, and those not coming from the outside
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state NEW ! -i eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o eth1 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing connections from the LAN side.
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT

# Masquerade.
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Dont forward from the outside to the inside.
iptables -A FORWARD -i eth0 -o eth0 -j REJECT

# Example pinhole: forward packets on port 5900 to 192.168.1.100
iptables -A FORWARD -i eth0 -o eth1 -p tcp --dport 5900 -j ACCEPT
iptables -A PREROUTING -t nat -p tcp --dport 5900 -j DNAT --to-destination 192.168.1.100

# Enable routing.
echo 1 > /proc/sys/net/ipv4/ip_forward

