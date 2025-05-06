#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/finkerle/ProxmoxVED/refs/heads/configarr-new/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: finkerle
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/raydak-labs/configarr

APP="Configarr"
var_tags="arr"
var_cpu="1"
var_ram="512"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d /opt/configarr ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/raydak-labs/configarr/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')

    if [[ "${RELEASE}" != "$(cat /opt/configarr_version.txt)" ]] || [[ ! -f /opt/configarr_version.txt ]]; then

        msg_info "Stopping $APP"
        systemctl stop configarr-task.timer
        systemctl stop configarr-task.service
        msg_ok "Stopped $APP"

        msg_info "Updating $APP to v${RELEASE}"
        temp_file=$(mktemp)
        curl -fsSL "https://github.com/raydak-labs/configarr/archive/refs/tags/v${RELEASE}.zip" -o $temp_file
        unzip -q $temp_file
        mv /opt/configarr/config.yml /etc/configarr/config.yml
        rm -rf /opt/configarr
        mv "configarr-${RELEASE}/" /opt/configarr
        mv /etc/configarr/config.yml /opt/configarr/config.yml
        cd /opt/configarr
        pnpm install
        pnpm run build
        msg_ok "Updated $APP to v${RELEASE}"

        msg_info "Starting $APP"
        systemctl start configarr-task.timer
        msg_ok "Started configarr"

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
