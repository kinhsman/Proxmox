# Ignore Power Button Input

```
bash -c "grep -q '^HandlePowerKey=' /etc/systemd/logind.conf && sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf || echo 'HandlePowerKey=ignore' >> /etc/systemd/logind.conf; systemctl restart systemd-logind.service"
```
# Configure SMTP notifications to be relayed to Discord
https://github.com/kinhsman/Proxmox/blob/main/SMTP-to-Discord.md

# Mount OneDrive to Proxmox
https://github.com/kinhsman/Proxmox/blob/main/mount-onedrive-to-proxmox.md

# Mount a folder in the host to the LXC container:
1. Create a mount folder inside the LXC first:
   ```
   mkdir -p /mnt/mymedia
   ```
2. Power off the LXC and add the following to the LXC config file
   ```
   echo 'lxc.mount.entry: /mnt/onedrive mnt/mymedia none bind,ro 0 0' >> /etc/pve/lxc/<CTID>.confg
   ```
