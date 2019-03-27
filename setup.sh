#!/bin/bash

# This is a script you can run on Raspbian to set up mitmproxy on a Raspberry Pi.  This uses the wireless interface to set up an access point.  The wired interface is used to connect to the upstream network.
# Tested on Raspbian release 2018-11-13 with a Raspberry Pi 3 Model B V1.2

# Install dnsmasq, hostapd for IP assignment and an access point
sudo apt-get update
sudo apt-get install -y dnsmasq hostapd

# Build dependencies for python 3.7
sudo apt-get install -y build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libffi-dev

# Remove wpasupplicant so it doesn't interfere with our hostapd
sudo apt-get remove --purge -y wpasupplicant

# Assign a static ip to the wlan0 interface
sudo bash -c "echo 'interface wlan0' >> /etc/dhcpcd.conf"
sudo bash -c "echo 'static ip_address=172.24.1.1/24' >> /etc/dhcpcd.conf"

# Download the hostapd config, enable the service
sudo wget -O /etc/hostapd/hostapd.conf https://raw.githubusercontent.com/Hainish/RaspberryPi-Packet-Sniffer/master/hostapd.conf
sudo bash -c "echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd"
sudo systemctl unmask hostapd.service
sudo systemctl enable hostapd

# Download the dnsmasq config, enable the service
sudo wget -O /etc/dnsmasq.conf https://raw.githubusercontent.com/Hainish/RaspberryPi-Packet-Sniffer/master/dnsmasq.conf
sudo systemctl enable dnsmasq

# Make sure packet forwarding is enabled on boot
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# Set up routing iptables rules and ensure they are applied on boot
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
sudo sh -c 'iptables-save > /etc/iptables.ipv4.nat'
sudo bash -c 'echo "iptables-restore < /etc/iptables.ipv4.nat" > /lib/dhcpcd/dhcpcd-hooks/70-ipv4-nat'

# Download, build, and install python 3.7.3
wget https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz
tar -zxvf Python-3.7.3.tgz
cd Python-3.7.3
./configure
make
sudo make install
cd ..

# Install the latest mitmproxy and download a script which forwards http & https requests through it
sudo pip3.7 install mitmproxy
wget https://raw.githubusercontent.com/Hainish/RaspberryPi-Packet-Sniffer/master/mitm.sh
chmod +x mitm.sh

# Reboot to start dnsmasq, hostapd and apply ip forwarding.
# mitm.sh has to be run manually to start MITMing traffic
sudo reboot
