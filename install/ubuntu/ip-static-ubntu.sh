#!/bin/bash
HOSTNAME="calcium"
IPADDR="192.168.2.112"
GATEWAY="192.168.2.1"
IFACE="ens33"  # Adjust if needed
DNS="192.168.2.1"

# Set hostname
echo "Setting hostname to $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME"
echo "$HOSTNAME" > /etc/hostname

# Backup existing netplan configs
echo "Backing up existing netplan config files..."
for f in /etc/netplan/*.yaml; do
  [ -e "$f" ] && mv "$f" "${f%.yaml}.pak"
done

# Create new netplan config
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

# Fix permissions
chmod 600 /etc/netplan/01-static.yaml

# Apply the network config
netplan apply

# Verify
ip a show "$IFACE"


