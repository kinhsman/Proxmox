# bash -c "$(curl -fsSL <url>)"
#!/bin/bash

# Disable default MOTD scripts
chmod -x /etc/update-motd.d/*

# Clear existing MOTD file
truncate -s 0 /etc/motd

# Create and populate custom LXC MOTD script
cat << 'EOF' > /etc/profile.d/00_lxc-details.sh
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
EOF

# Make the script executable (optional, but ensures it runs)
chmod +x /etc/profile.d/00_lxc-details.sh

echo "Custom LXC MOTD setup completed."
