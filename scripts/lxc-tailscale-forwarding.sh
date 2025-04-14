#!/bin/bash

set -e

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root (use sudo)."
  exit 1
fi

echo "[+] Updating package list and installing ethtool..."
apt update && apt install -y ethtool

echo "[+] Detecting default network interface..."
NETDEV=$(ip -o route get 8.8.8.8 | awk '{print $5}')
echo "[+] Found interface: $NETDEV"

echo "[+] Enabling UDP offloading..."
ethtool -K "$NETDEV" rx-udp-gro-forwarding on rx-gro-list off

echo "[+] Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf
systemctl enable tailscaled
systemctl start tailscaled
echo "[+] Verifying Tailscale status..."
systemctl status tailscaled.service | grep -e Status -e Active
echo "[✓] Done! Tailscale forwarding enabled."
