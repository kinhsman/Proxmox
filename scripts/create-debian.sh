#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/build.func)


APP="Debian"
var_tags="${var_tags:-os}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /var ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated $APP LXC"
  exit
}


build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"

APP="Debian"
var_tags="os"
var_cpu="1"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="12"
var_unprivileged="1"

DISABLEIP6="yes"
VERB="yes"
PW=""
METHOD="default"

base_settings "$VERB"
header_info
variables
color
catch_errors

# Manual prompts for hostname, CT ID, disk size only
echo -n "Enter Container ID: "
read CT_ID
echo -n "Enter Hostname: "
read HN
echo -n "Enter Disk Size (in GB): "
read DISK_SIZE

build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
