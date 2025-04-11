# Ignore Power Button Input
   ```
   bash -c "grep -q '^HandlePowerKey=' /etc/systemd/logind.conf && sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf || echo 'HandlePowerKey=ignore' >> /etc/systemd/logind.conf; systemctl restart systemd-logind.service"
   ```
# Mount a folder in the host to the LXC container:
1. Create a mount folder inside the LXC first:
   ```
   mkdir -p /mnt/mymedia
   ```
2. Power off the LXC and add the following to the LXC config file
   ```
   echo 'lxc.mount.entry: /mnt/onedrive mnt/mymedia none bind,ro 0 0' >> /etc/pve/lxc/<CTID>.confg
   ```

# Configure SMTP notifications to be relayed to Discord
   https://github.com/kinhsman/Proxmox/blob/main/SMTP-to-Discord.md

# Mount OneDrive to Proxmox
   https://github.com/kinhsman/Proxmox/blob/main/mount-onedrive-to-proxmox.md

# Edit the login banner for Docker LXC
   ```
   nano /etc/profile.d/00_lxc-details.sh 
   ```
   ```
   echo -e ""
   echo ""
   echo -e "    🖥️  \e[m\e[33m OS: \e[1;92mDebian GNU/Linux - Version: 12\e[m"
   echo -e "    🏠  \e[m\e[33m Hostname: \e[1;92m$(hostname)\e[m"
   echo -e "    💡  \e[m\e[33m IP Address: \e[1;92m$(hostname -I | awk '{print $1}')\e[m"
   echo -e "    🐳  \e[m\e[33m Running Docker Containers:\e[m"
   for container in $(docker ps -a --format '{{.Names}}' | sort); do
       printf "          \e[1;92m%s\e[m\n" "$container"
   done
   ```
