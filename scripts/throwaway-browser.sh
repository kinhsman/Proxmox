#!/bin/bash
# Throwaway browser: a full Chromium you open from any other browser, running on this Debian box.
#
#   Install:    bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)"
#   Options:    BROWSER_USER=me BROWSER_PASS=secret BROWSER_DNS=10.0.0.1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)"
#   Remove:     bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)" -- uninstall
#
# Options (all optional):
#   BROWSER_USER   login name            (default: user)
#   BROWSER_PASS   login password        (default: random; a re-run keeps the saved one)
#   BROWSER_DNS    DNS server to use     (default: whatever this box uses)
#   BROWSER_TZ     time zone             (default: this box's)
#   BROWSER_PORT   HTTPS port            (default: 3001)
#
# In a Proxmox LXC the container needs nesting on. On the Proxmox host:
#   pct set <CTID> --features nesting=1,keyctl=1 && pct reboot <CTID>
set -euo pipefail

NAME=throwaway-browser
INFO=/root/browser-login.txt
IMAGE=lscr.io/linuxserver/chromium:latest
WATCHDOG=/usr/local/bin/browser-watchdog.sh
UNIT=/etc/systemd/system/browser-watchdog.service

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root"

if [ "${1:-}" = uninstall ]; then
  say "Removing the throwaway browser"
  systemctl disable --now browser-watchdog 2>/dev/null || true
  rm -f "$WATCHDOG" "$UNIT"; systemctl daemon-reload 2>/dev/null || true
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
PORT=${BROWSER_PORT:-3001}
TZ_NAME=${BROWSER_TZ:-$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo UTC)}
DNS_ARGS=()
[ -n "${BROWSER_DNS:-}" ] && DNS_ARGS=(--dns "$BROWSER_DNS")

# 3. The browser
say "Downloading the browser (about 1.5 GB the first time)"
docker pull -q "$IMAGE" >/dev/null
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
  --restart unless-stopped \
  --security-opt seccomp=unconfined \
  --shm-size 1g \
  "${DNS_ARGS[@]}" \
  -e TZ="$TZ_NAME" -e PUID=1000 -e PGID=1000 \
  -e CUSTOM_USER="$USER_NAME" -e PASSWORD="$PASS" \
  -e TITLE="Throwaway browser" \
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
    -e WAYLAND_DISPLAY=\$WD -e XDG_RUNTIME_DIR=/config/.XDG \$C wrapped-chromium
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

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
URL="https://${IP:-<this-box-ip>}:$PORT/"
umask 077
printf 'URL: %s\nUser: %s\nPassword: %s\n' "$URL" "$USER_NAME" "$PASS" > "$INFO"

cat <<EOF

  Throwaway browser is ready

  URL:       $URL
  User:      $USER_NAME
  Password:  $PASS

  Your browser will warn about the certificate the first time: click Advanced, then Proceed.
  Saved to $INFO
  Remove it: bash -c "$(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/throwaway-browser.sh)" -- uninstall

EOF
