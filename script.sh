#!/bin/bash
localdir=$(pwd);
currentUSER="$USERNAME";
equal="==================================================";

echo "$equal";
echo "start download programs";
apt update;
apt install sudo -y;
sudo apt install iptables -y;
sudo apt install isc-dhcp-server -y;
sudo apt install bind9 -y;
sudo apt install rcconf -y;
sudo apt install sysv-rc-conf -y;
echo "end download programs";
echo "$equal";
echo "$equal";
echo "configuring network interfaces!";
echo "inform WAN 1 interface 'ex: enp0s3'.";
read IWAN1;

if [ -z "$IWAN1" ]; then
    IWAN1="enp0s3";
fi

echo "inform LAN 1 interface 'ex: enp0s8'.";
read ILAN1;

if [ -z "$ILAN1" ]; then
    ILAN1="enp0s8";
fi

echo "inform LAN 1 address 'ex: 10.1.14.1'.";
read ILAN1address;

if [ -z "$ILAN1address" ]; then
    ILAN1address="10.1.14.1";
fi

echo "inform LAN 1 netmask 'ex: 255.255.255.0'.";
read ILAN1netmask;

if [ -z "$ILAN1netmask" ]; then
    ILAN1netmask="255.255.255.0";
fi

echo "inform LAN 1 network 'ex: 10.1.14.0'.";
read ILAN1network;

if [ -z "$ILAN1network" ]; then
    ILAN1network="10.1.14.0";
fi

echo "inform LAN 1 broadcast 'ex: 10.1.14.255'.";
read ILAN1broadcast;

if [ -z "$ILAN1broadcast" ]; then
    ILAN1broadcast="10.1.14.255";
fi

echo "inform LAN 1 Range Start 'ex: 10.1.14.20'.";
read ILAN1RangeStart;

if [ -z "$ILAN1RangeStart" ]; then
    ILAN1RangeStart="10.1.14.21";
fi

echo "inform LAN 1 Range Stop 'ex: 10.1.14.199'.";
read ILAN1RangeStop;

if [ -z "$ILAN1RangeStop" ]; then
    ILAN1RangeStop="10.1.14.199";
fi

echo "create file .bkp with /etc/network/interfaces.";
mv /etc/network/interfaces /etc/network/interfaces.bkp;

echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

#wan
#the primary network interface
allow-hotplug $IWAN1
auto $IWAN1
iface $IWAN1 inet dhcp

#lan
#the secondary network interface
allow-hotplug $ILAN1
auto $ILAN1
iface $ILAN1 inet static
address $ILAN1address
netmask $ILAN1netmask
network $ILAN1network
broadcast $ILAN1broadcast
" > /etc/network/interfaces;

echo '$cat in interfaces file configuration.';
cat /etc/network/interfaces;

echo "finished file edition;"
echo "start restart services";
sudo systemctl stop NetworkManager;
sudo systemctl disable NetworkManager;
sudo systemctl status NetworkManager | more;
sudo systemctl restart networking;
sudo systemctl start networking;
sudo systemctl status networking | more;
echo $equal;
echo $equal;

echo "start Configure DHCP server on interface $ILAN1";

echo "create file .bkp with /etc/default/isc-dhcp-server.";
mv /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bkp;

echo "add configuration in file";
echo 'INTERFACES="'$ILAN1'"' > /etc/default/isc-dhcp-server
cat /etc/default/isc-dhcp-server
echo "finished file edition;"

echo "create file .bkp with /etc/dhcp/dhcpd.conf.";
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.bkp

echo "add configuration in file";
echo "
option domain-name-servers $ILAN1address;

default-lease-time 86400;
max-lease-time 604800;

ddns-update-style none;

authoritative;

log-facility local7;

subnet $ILAN1network netmask $ILAN1netmask {
  range $ILAN1RangeStart $ILAN1RangeStop;
  option routers $ILAN1address;
}" > /etc/dhcp/dhcpd.conf
cat /etc/dhcp/dhcpd.conf
echo "finished file edition;"

echo "start restart services";
sudo systemctl restart isc-dhcp-server;
sudo systemctl start isc-dhcp-server;
sudo systemctl status isc-dhcp-server | more;

echo "monitoring clients DHCP";
cat /var/lib/dhcp/dhcpd.leases;
echo $equal;
echo $equal;

echo "active routing packages and NAT.";
sudo echo 1 > /proc/sys/net/ipv4/ip_forward;
sudo modprobe iptable_nat;
sudo iptables -t nat -A POSTROUTING -o $IWAN1 -j MASQUERADE;

echo "create script to startup config NAT and routing.";
sudo mkdir /var/local/log/;
 
echo "#!/bin/bash
# Active Routing Packages
sudo echo 1 > /proc/sys/net/ipv4/ip_forward;
sudo modprobe iptable_nat;
sudo iptables -t nat -A POSTROUTING -o $IWAN1 -j MASQUERADE;
" > /etc/init.d/ActiveNATandRouting;
chmod +x /etc/init.d/ActiveNATandRouting;
cat /etc/init.d/ActiveNATandRouting;
rcconf;
sudo sysv-rc-conf;
echo $equal;
echo $equal;

echo "start config DNS Server;"

sudo echo "nameserver $ILAN1address
nameserver 80.80.80.80
nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.conf
cat /etc/resolv.conf;

echo "start restart services";
sudo systemctl restart bind9;
sudo systemctl start bind9;
sudo systemctl status bind9 | more;
echo "end config DNS Server;"
echo $equal;
