# Ignore Power Button Input

```
bash -c "grep -q '^HandlePowerKey=' /etc/systemd/logind.conf && sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf || echo 'HandlePowerKey=ignore' >> /etc/systemd/logind.conf; systemctl restart systemd-logind.service"
```
# Configure SMTP notifications to be relayed to Discord
https://github.com/kinhsman/Proxmox/blob/main/SMTP-to-Discord.md

# Mount OneDrive to Proxmox

