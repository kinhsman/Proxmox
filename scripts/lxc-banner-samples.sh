### Docker LXC example
### nano /etc/profile.d/00_lxc-details.sh
### chmod -x /etc/update-motd.d/*
### truncate -s 0 /etc/motd
#!/bin/bash

echo
echo -e "\e[1;92m         DOCKER SERVER\e[0m"
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

###################

### Jellyfin LXC
#!/bin/bash

echo
echo -e "\033[1;92m        Jellyfin Media Server\033[0m"
echo
echo -e "    🖥️   \033[0m\033[33m OS:       \033[1;92m$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')\033[0m"
echo -e "    🏠   \033[0m\033[33m Hostname: \033[1;92m$(hostname)\033[0m"
echo -e "    💡   \033[0m\033[33m Address : \033[1;92mhttp://$(hostname -I | awk '{print $1}'):8096\033[0m"
echo
echo

########################
### WireGuard Dashboard VPN Server
#!/bin/bash

echo
echo -e "\033[1;92m         WireGuard Dashboard VPN Server\033[0m"
echo
echo -e "    🖥️   \033[0m\033[33m OS:       \033[1;92m$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')\033[0m"
echo -e "    🏠   \033[0m\033[33m Hostname: \033[1;92m$(hostname)\033[0m"
echo -e "    💡   \033[0m\033[33m Address:  \033[1;92mhttp://$(hostname -I | awk '{print $1}'):10086\033[0m"
echo
echo
