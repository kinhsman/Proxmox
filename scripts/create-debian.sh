#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/kinhsman/ProxmoxVE/main/misc/build.func)

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
CT_TYPE="1" # Must define this before base_settings
METHOD="default"

header_info
variables
color
catch_errors

# Prompt for minimal required inputs
echo -n "Enter Container ID: "
read CT_ID
echo -n "Enter Hostname: "
read HN
echo -n "Enter Disk Size (in GB): "
read DISK_SIZE

base_settings "$VERB"  # Must be called after CT_ID etc. are read

build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
