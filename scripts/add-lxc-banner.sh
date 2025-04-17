#!/bin/bash
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/refs/heads/main/scripts/add-lxc-banner.sh)"
# Prompt user for service name and port
read -p "Enter service name (e.g., NGINX Proxy Manager): " SERVICE_NAME
read -p "Enter port number (e.g., 81): " PORT

# Disable default MOTD scripts
chmod -x /etc/update-motd.d/*

# Clear existing MOTD file
truncate -s 0 /etc/motd

# Create and populate custom LXC MOTD script
cat << EOF > /etc/profile.d/00_lxc-details.sh
echo
echo -e "\033[1;92m        \$SERVICE_NAME\033[0m"
echo
echo -e "    🖥️  \033[0m\033[33m OS:       \033[1;92m\$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')\033[0m"
echo -e "    🏠  \033[0m\033[33m Hostname: \033[1;92m\$(hostname)\033[0m"
echo -e "    💡  \033[0m\033[33m Address : \033[1;92mhttp://\$(hostname -I | awk '{print \$1}'):\$PORT\033[0m"
echo
EOF

# Make the script executable (optional, but ensures it runs)
chmod +x /etc/profile.d/00_lxc-details.sh

echo "Custom LXC MOTD setup completed."
