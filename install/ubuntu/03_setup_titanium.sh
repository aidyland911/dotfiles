#!/bin/bash
HOSTNAME="Titanium"
IPADDR="10.1.1.22"
GATEWAY="10.1.1.254"
IFACE="ens160"
DNS="10.1.1.254"

echo "Setting hostname to $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME"
echo "$HOSTNAME" > /etc/hostname

echo "Backing up existing netplan configs..."
for f in /etc/netplan/*.yaml; do
  [ -e "$f" ] && mv "$f" "${f%.yaml}.pak"
done

tee /etc/netplan/01-static.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: no
      addresses: [$IPADDR/24]
      nameservers:
        addresses: [$DNS]
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
EOF

chmod 600 /etc/netplan/01-static.yaml
netplan apply
ip a show "$IFACE"
