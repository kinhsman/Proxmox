### Docker LXC example
### nano /etc/profile.d/00_lxc-details.sh
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
