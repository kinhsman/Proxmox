#!/bin/bash
# Throwaway browser: a full Chromium you open from any other browser, with a login.
#
# Run it in the Proxmox host shell: it makes a new Debian LXC, sets it all up inside, and prints
# the URL, user and password. Run it inside an existing Debian LXC or box: it sets up that box.
# Every shell login shows the URL and login again. In an LXC it made, the Proxmox Console logs
# in as root by itself.
#
#   Install:    bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)"
#   Options:    BROWSER_USER=me BROWSER_PASS=secret BROWSER_DNS=10.0.0.1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)"
#   Remove:     on Proxmox: pct stop <CTID> && pct destroy <CTID>
#               inside a box: bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)" -- uninstall
#
# Options (all optional):
#   BROWSER_USER     login name            (default: user)
#   BROWSER_PASS     login password        (default: random; a re-run keeps the saved one)
#   BROWSER_DNS      DNS server to use     (default: whatever the box uses)
#   BROWSER_TZ       time zone             (default: this box's)
#   BROWSER_PORT     HTTPS port            (default: 3001)
# Proxmox host only:
#   BROWSER_CTID     container ID          (default: next free)
#   BROWSER_HOSTNAME container name        (default: throwaway-browser)
#   BROWSER_BRIDGE   network bridge        (default: vmbr0)
#   BROWSER_STORAGE  disk storage          (default: local-lvm, else the first that holds containers)
#
# An existing LXC needs nesting on. On the Proxmox host:
#   pct set <CTID> --features nesting=1,keyctl=1 && pct reboot <CTID>
set -euo pipefail

SCRIPT_URL=https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh
NAME=throwaway-browser
INFO=/root/browser-login.txt
IMAGE=lscr.io/linuxserver/chromium:latest
WATCHDOG=/usr/local/bin/browser-watchdog.sh
UNIT=/etc/systemd/system/browser-watchdog.service
WELCOME=/etc/profile.d/throwaway-browser.sh
AUTOLOGIN=/etc/systemd/system/container-getty@1.service.d/autologin.conf

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root"

# ---------------------------------------------------------------------------------------------
# On a Proxmox host: make the LXC, then run this same script inside it.
# ---------------------------------------------------------------------------------------------
if command -v pct >/dev/null && [ -d /etc/pve ]; then
  [ "${1:-}" = uninstall ] && die "on Proxmox, remove the container instead: pct stop <CTID> && pct destroy <CTID>"
  CTID=${BROWSER_CTID:-$(pvesh get /cluster/nextid)}
  HOST=${BROWSER_HOSTNAME:-throwaway-browser}
  BRIDGE=${BROWSER_BRIDGE:-vmbr0}
  pct status "$CTID" >/dev/null 2>&1 && die "container $CTID already exists; pick another with BROWSER_CTID=<id>"

  STORE=${BROWSER_STORAGE:-}
  if [ -z "$STORE" ]; then
    ROOTDIRS=$(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 && $3=="active"{print $1}')
    STORE=$(echo "$ROOTDIRS" | grep -x local-lvm || echo "$ROOTDIRS" | head -1)
  fi
  [ -n "$STORE" ] || die "no storage can hold containers; set BROWSER_STORAGE=<name>"

  # Newest Debian 12 or 13 template already here, else download Debian 12.
  TMPL=$(for s in $(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 && $3=="active"{print $1}'); do
           pveam list "$s" 2>/dev/null | awk 'NR>1{print $1}'; done | grep -E 'debian-1[23]-standard_' | sort -t_ -k2 -V | tail -1)
  if [ -z "$TMPL" ]; then
    TSTORE=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 && $3=="active"{print $1}' | head -1)
    [ -n "$TSTORE" ] || die "no storage can hold templates"
    say "Downloading the Debian 12 template"
    pveam update >/dev/null
    T=$(pveam available --section system | awk '{print $2}' | grep -E '^debian-12-standard_' | sort -V | tail -1)
    [ -n "$T" ] || die "could not find a Debian 12 template to download"
    pveam download "$TSTORE" "$T" >/dev/null
    TMPL="$TSTORE:vztmpl/$T"
  fi

  say "Making LXC $CTID ($HOST) on $STORE from ${TMPL##*/}"
  pct create "$CTID" "$TMPL" --hostname "$HOST" --cores 2 --memory 2048 --swap 512 \
    --rootfs "$STORE:10" --net0 "name=eth0,bridge=$BRIDGE,ip=dhcp" \
    --unprivileged 1 --features nesting=1,keyctl=1 --onboot 0 \
    --description "Throwaway browser. Remove: pct stop $CTID && pct destroy $CTID" >/dev/null
  pct start "$CTID"

  say "Waiting for the network"
  for _ in $(seq 1 60); do
    pct exec "$CTID" -- getent hosts deb.debian.org >/dev/null 2>&1 && break
    sleep 2
  done
  pct exec "$CTID" -- getent hosts deb.debian.org >/dev/null 2>&1 \
    || die "LXC $CTID has no internet (DHCP on $BRIDGE?). Remove it: pct stop $CTID && pct destroy $CTID"

  # Hand this very script to the container: the file when run as one, else the text bash -c got.
  TMP=$(mktemp)
  if [ -f "$0" ] && grep -q 'Throwaway browser' "$0" 2>/dev/null; then cp "$0" "$TMP"
  elif [ -n "${BASH_EXECUTION_STRING:-}" ]; then printf '%s\n' "$BASH_EXECUTION_STRING" > "$TMP"
  else curl -fsSL "$SCRIPT_URL" -o "$TMP"; fi
  pct push "$CTID" "$TMP" /root/throwaway-browser.sh --perms 755
  rm -f "$TMP"

  TZ_HOST=${BROWSER_TZ:-$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo UTC)}
  pct exec "$CTID" -- env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/root LANG=C.UTF-8 TERM=xterm \
    BROWSER_USER="${BROWSER_USER:-}" BROWSER_PASS="${BROWSER_PASS:-}" BROWSER_DNS="${BROWSER_DNS:-}" \
    BROWSER_TZ="$TZ_HOST" BROWSER_PORT="${BROWSER_PORT:-}" BROWSER_IN_LXC="$CTID" \
    bash /root/throwaway-browser.sh
  exit 0
fi

if [ "${1:-}" = uninstall ]; then
  say "Removing the throwaway browser"
  systemctl disable --now browser-watchdog 2>/dev/null || true
  rm -f "$WATCHDOG" "$UNIT" "$WELCOME"; systemctl daemon-reload 2>/dev/null || true
  if command -v docker >/dev/null; then
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker volume rm "$NAME-config" >/dev/null 2>&1 || true
    docker image rm "$IMAGE" >/dev/null 2>&1 || true
  fi
  rm -f "$INFO"
  say "Done. Docker itself is left installed (apt purge docker.io to remove it)."
  exit 0
fi

grep -qiE 'debian|ubuntu' /etc/os-release || die "this script is for Debian or Ubuntu"

# 1. Docker
if ! command -v docker >/dev/null; then
  say "Installing Docker (a few minutes)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq docker.io curl openssl ca-certificates >/dev/null
fi
command -v curl >/dev/null || { apt-get update -qq; apt-get install -y -qq curl >/dev/null; }
systemctl enable --now docker >/dev/null 2>&1 || true
if ! docker info >/dev/null 2>&1; then
  die "Docker will not start. In a Proxmox LXC, turn nesting on from the Proxmox host:
  pct set <CTID> --features nesting=1,keyctl=1 && pct reboot <CTID>
then run this again."
fi

# 2. Login (a re-run keeps the saved password unless a new one is given)
USER_NAME=${BROWSER_USER:-}
PASS=${BROWSER_PASS:-}
if [ -f "$INFO" ]; then
  [ -n "$USER_NAME" ] || USER_NAME=$(sed -n 's/^User: *//p' "$INFO")
  [ -n "$PASS" ] || PASS=$(sed -n 's/^Password: *//p' "$INFO")
fi
USER_NAME=${USER_NAME:-user}
PASS=${PASS:-$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 14)}
PORT=${BROWSER_PORT:-3001}; [ -n "$PORT" ] || PORT=3001
TZ_NAME=${BROWSER_TZ:-$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo UTC)}
DNS_ARGS=()
[ -n "${BROWSER_DNS:-}" ] && DNS_ARGS=(--dns "$BROWSER_DNS")

# 3. The browser
say "Downloading the browser (about 1.5 GB the first time)"
docker pull -q "$IMAGE" >/dev/null
docker stop -t 15 "$NAME" >/dev/null 2>&1 || true
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
  --restart unless-stopped \
  --security-opt seccomp=unconfined \
  --shm-size 1g \
  "${DNS_ARGS[@]}" \
  -e TZ="$TZ_NAME" -e PUID=1000 -e PGID=1000 \
  -e CUSTOM_USER="$USER_NAME" -e PASSWORD="$PASS" \
  -e TITLE="Throwaway browser" \
  -e CHROME_CLI="--hide-crash-restore-bubble" \
  -p "$PORT":3001 \
  -v "$NAME-config":/config \
  "$IMAGE" >/dev/null

# 4. Watchdog: closing the last tab quits Chromium and the screen goes black, so reopen it.
#    It must start on the window manager's own display; the other one is the raw screen,
#    and a window there comes up with no address bar.
cat > "$WATCHDOG" <<EOF
#!/bin/sh
C=$NAME
while true; do
  sleep 2
  docker ps -q -f name=^\$C\$ | grep -q . || continue
  docker exec \$C pgrep -f /usr/lib/chromium/chromium >/dev/null && continue
  LP=\$(pgrep -x labwc | head -1); [ -n "\$LP" ] || continue
  PARENT=\$(tr '\0' '\n' < /proc/\$LP/environ | sed -n 's/^WAYLAND_DISPLAY=//p')
  WD=\$(docker exec \$C sh -c 'ls /config/.XDG 2>/dev/null' | grep -E '^wayland-[0-9]+\$' | grep -vx "\$PARENT" | head -1)
  [ -n "\$WD" ] || continue
  sleep 1
  docker exec \$C pgrep -f /usr/lib/chromium/chromium >/dev/null && continue
  docker exec -d -u abc -e HOME=/config -e DISPLAY=:1 -e PIXELFLUX_WAYLAND=true \\
    -e WAYLAND_DISPLAY=\$WD -e XDG_RUNTIME_DIR=/config/.XDG \$C wrapped-chromium --hide-crash-restore-bubble
  logger -t $NAME "reopened chromium"
  sleep 5
done
EOF
chmod 755 "$WATCHDOG"
cat > "$UNIT" <<EOF
[Unit]
Description=Reopen Chromium in the throwaway browser
After=docker.service
[Service]
ExecStart=$WATCHDOG
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now browser-watchdog >/dev/null 2>&1
systemctl restart browser-watchdog

# 5. Wait until the page answers
say "Starting up"
for _ in $(seq 1 90); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/" || true)
  [ "$code" = 401 ] || [ "$code" = 200 ] && break
  sleep 2
done
[ "$code" = 401 ] || [ "$code" = 200 ] || die "the browser did not come up; see: docker logs $NAME"

# 6. Welcome screen: every login shell shows the URL and login (read fresh, so a new IP shows).
cat > "$WELCOME" <<EOF
# Throwaway browser login, shown at every shell login. Added by throwaway-browser.sh.
case \$- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac
[ -r $INFO ] || return 0 2>/dev/null || exit 0
_tb_ip=\$(hostname -I 2>/dev/null | awk '{print \$1}')
_tb_user=\$(sed -n 's/^User: *//p' $INFO)
_tb_pass=\$(sed -n 's/^Password: *//p' $INFO)
_tb_state=\$(docker inspect -f '{{.State.Status}}' $NAME 2>/dev/null || echo "not found")
printf '\n  \033[1;36mThrowaway browser\033[0m (%s)\n' "\$_tb_state"
printf '  \033[33mURL:\033[0m       \033[1;32mhttps://%s:$PORT/\033[0m\n' "\${_tb_ip:-<this-box-ip>}"
printf '  \033[33mUser:\033[0m      \033[1;32m%s\033[0m\n' "\$_tb_user"
printf '  \033[33mPassword:\033[0m  \033[1;32m%s\033[0m\n\n' "\$_tb_pass"
unset _tb_ip _tb_user _tb_pass _tb_state
EOF
chmod 644 "$WELCOME"

# 7. In an LXC this script made, the Proxmox Console logs in as root by itself.
if [ -n "${BROWSER_IN_LXC:-}" ]; then
  mkdir -p "$(dirname "$AUTOLOGIN")"
  cat > "$AUTOLOGIN" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 $TERM
EOF
  systemctl daemon-reload
  systemctl restart container-getty@1.service 2>/dev/null || true
fi

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
URL="https://${IP:-<this-box-ip>}:$PORT/"
if [ -n "${BROWSER_IN_LXC:-}" ]; then
  REMOVE="on the Proxmox host: pct stop $BROWSER_IN_LXC && pct destroy $BROWSER_IN_LXC"
else
  REMOVE="bash -c \"\$(curl -fsSL $SCRIPT_URL)\" -- uninstall"
fi
umask 077
printf 'URL: %s\nUser: %s\nPassword: %s\n' "$URL" "$USER_NAME" "$PASS" > "$INFO"

cat <<EOF

  Throwaway browser is ready

  URL:       $URL
  User:      $USER_NAME
  Password:  $PASS

  Your browser will warn about the certificate the first time: click Advanced, then Proceed.
  Saved to $INFO
  Remove it: $REMOVE

EOF
