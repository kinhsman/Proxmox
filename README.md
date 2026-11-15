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
   echo 'lxc.mount.entry: /mnt/onedrive mnt/mymedia none bind,ro 0 0' >> /etc/pve/lxc/<CTID>.conf
   ```

# Configure SMTP notifications to be relayed to Discord
   https://github.com/kinhsman/Proxmox/blob/main/SMTP-to-Discord.md

# Mount OneDrive to Proxmox
   https://github.com/kinhsman/Proxmox/blob/main/mount-onedrive-to-proxmox.md

# Edit the login banner for Docker LXC
   ```
   chmod -x /etc/update-motd.d/*
   truncate -s 0 /etc/motd
   echo > /etc/profile.d/00_lxc-details.sh 
   nano /etc/profile.d/00_lxc-details.sh 
   ```
   ```
   echo
   echo -e "\e[1;92m         Docker Server LXC\e[0m"
   echo
   echo -e "    🖥️  \e[0m\e[33m  OS: \e[1;92m$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')\e[0m"
   echo -e "    🏠  \e[0m\e[33m Hostname: \e[1;92m$(hostname)\e[0m"
   echo -e "    💡  \e[0m\e[33m IP Address: \e[1;92m$(hostname -I | awk '{print $1}')\e[0m"
   echo -e "    🐳  \e[0m\e[33m Running Docker Containers:\e[0m"
   
   for container in $(docker ps -a --format '{{.Names}}' | sort); do
       ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{printf "%s -> %s\n" $p (index $conf 0).HostPort}}{{end}}{{end}}' "$container" | paste -sd ", " -)
       if [ -z "$ports" ]; then
           ports="No published ports"
       fi
       printf "          \e[1;92m%-20s\e[0m \e[36m%s\e[0m\n" "$container" "$ports"
   done
   
   echo
   echo
   ```

# Throwaway browser in a Debian LXC
A full Chromium you open from any other browser, with a login. Handy for testing a site from another network (for example, through a hotel or VPN exit). Closing the last tab reopens Chromium instead of leaving a black screen.

1. On the Proxmox host, turn nesting on for the LXC:
   ```
   pct set <CTID> --features nesting=1,keyctl=1 && pct reboot <CTID>
   ```
2. Inside the LXC (Debian 12 or 13), as root. It prints the URL, user and password at the end:
   ```
   apt-get update -qq && apt-get install -y -qq curl && bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)"
   ```
   Options: `BROWSER_USER=me BROWSER_PASS=secret BROWSER_DNS=10.0.0.1 bash -c "$(curl -fsSL ...)"`

   Remove it:
   ```
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)" -- uninstall
   ```
   Needs 2 cores, 2 GB RAM and 10 GB disk. The first run downloads about 1.5 GB.
