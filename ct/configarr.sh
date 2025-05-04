#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/finkerle/ProxmoxVED/refs/heads/configarr-new/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: [YourUserName]
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: [SOURCE_URL]

# App Default Values
APP="Configarr"
# Name of the app (e.g. Google, Adventurelog, Apache-Guacamole"
var_tags="arr"
# Tags for Proxmox VE, maximum 2 pcs., no spaces allowed, separated by a semicolon ; (e.g. database | adblock;dhcp)
var_cpu="1"
# Number of cores (1-X) (e.g. 4) - default are 2
var_ram="512"
# Amount of used RAM in MB (e.g. 2048 or 4096)
var_disk="4"
# Amount of used disk space in GB (e.g. 4 or 10)
var_os="debian"
# Default OS (e.g. debian, ubuntu, alpine)
var_version="12"
# Default OS version (e.g. 12 for debian, 24.04 for ubuntu, 3.20 for alpine)
var_unprivileged="1"
# 1 = unprivileged container, 0 = privileged container

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    # Check if installation is present | -f for file, -d for folder
    if [[ ! -d /opt/configarr ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    # Crawling the new version and checking whether an update is required
    RELEASE=$(curl -fsSL https://api.github.com/repos/raydak-labs/configarr/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')

    if [[ "${RELEASE}" != "$(cat /opt/configarr_version.txt)" ]] || [[ ! -f /opt/configarr_version.txt ]]; then
        # Stopping Services
        msg_info "Stopping $APP"
        systemctl stop configarr-task.timer
        systemctl stop configarr-task.service
        msg_ok "Stopped $APP"

        # Execute Update
        msg_info "Updating $APP to v${RELEASE}"
        temp_file=$(mktemp)
        curl -fsSL "https://github.com/raydak-labs/configarr/archive/refs/tags/v${RELEASE}.zip" -o $temp_file
        unzip -q $temp_file
        rm -rf /opt/configarr
        mv "configarr-${RELEASE}/" /opt/configarr
        cd /opt/configarr
        pnpm install
        pnpm run build
        msg_ok "Updated $APP to v${RELEASE}"

        # Starting Services
        msg_info "Starting $APP"
        systemctl start configarr-task.timer
        systemctl start configarr-task.service
        msg_ok "Started $APP"

        # Last Action
        echo "${RELEASE}" >/opt/configarr_version.txt
        msg_ok "Update Successful"
    else
        msg_ok "No update required. ${APP} is already at v${RELEASE}"
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:[PORT]${CL}"
