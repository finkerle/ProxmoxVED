#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: finkerle
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/raydak-labs/configarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    git
msg_ok "Installed Dependencies"

msg_info "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
msg_ok "Set up Node.js Repository"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
$STD npm install -g pnpm
msg_ok "Installed Node.js"

msg_info "Installing Configarr"

temp_file=$(mktemp)
RELEASE=$(curl -fsSL https://api.github.com/repos/raydak-labs/configarr/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
curl -fsSL "https://github.com/raydak-labs/configarr/archive/refs/tags/v${RELEASE}.zip" -o $temp_file
$STD unzip -q $temp_file -d /opt/configarr

msg_info "Setup ${APPLICATION}"
mkdir -p /opt/configarr/repos
mkdir -p /opt/configarr/templates
cat <<EOF >/etc/configarr/.env
ROOT_PATH=/opt/configarr
CUSTOM_REPO_ROOT=/etc/configarr/repos
CONFIG_LOCATION=/etc/configarr/config.yml
SECRETS_LOCATION=/etc/configarr/secrets.yml
#DRY_RUN=true # not fully supported yet
#LOAD_LOCAL_SAMPLES=false
#DEBUG_CREATE_FILES=false
#LOG_LEVEL=info
EOF
mv /opt/configarr/secrets.yml.template /etc/configarr/secrets.yml
sed 's|#localConfigTemplatesPath: /app/templates|#localConfigTemplatesPath: /opt/configarr/templates|' config.yml.template >/etc/configarr/config.yml
cd /opt/configarr
$STD pnpm install
$STD pnpm run build
echo "${RELEASE}" >/opt/configarr_version.txt
msg_ok "Setup ${APPLICATION}"

# Creating Service (if needed)
msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/configarr-task.service

[Unit]
Description=Run Configarr Task

[Service]
Type=oneshot
WorkingDirectory=/opt/configarr
ExecStart=/usr/bin/node /opt/configarr/bundle.cjs

EOF
cat <<EOF >/etc/systemd/system/configarr-task.timer

[Unit]
Description=Run Configarr every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target

EOF
systemctl enable -q --now configarr-task.timer
systemctl enable -q --now configarr-task.service
msg_ok "Created Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f $temp_file
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
