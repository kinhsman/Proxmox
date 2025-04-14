[source: 246] #!/usr/bin/env bash
# MODIFIED: Updated source URL to point to the community-scripts repository if that was intended
# If your 'build.func' is local, adjust the source line accordingly.
# Example: source /path/to/your/modified/build.func
source <(curl -fsSL https://raw.githubusercontent.com/kinhsman/Proxmox/main/scripts/build.func) # Or your local path

APP="Debian"
var_tags="${var_tags:-os}"
var_cpu="${var_cpu:-1}"        # Default CPU cores
var_ram="${var_ram:-512}"       # Default RAM in MiB
var_disk="${var_disk:-2}"       # Default Disk size in GB (Will be prompted)
var_os="${var_os:-debian}"      # Default OS type
var_version="${var_version:-12}"  # Default OS version
var_unprivileged="${var_unprivileged:-1}" # Default container type (1=unprivileged)

# These variables provide defaults that base_settings in build.func will use.
# The modified build.func ensures only Container ID, Hostname, and Disk Size are prompted.

header_info "$APP"
variables
color
catch_errors

# update_script function remains unchanged for in-container updates
function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ !
[source: 247] -d /var ]]; then
    msg_error "No ${APP} Installation Found!"
[source: 248] exit
  fi
  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  msg_ok "Updated $APP LXC"
  exit
}

# Call start function from the modified build.func
start

# Call build_container from the modified build.func
build_container

# Call description function from the modified build.func
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
