#!/bin/bash
LATEST_VERSION=$(curl https://discord.com/api/download/stable?platform=linux | grep -Eo "https://.{1,}\.deb" | awk -F "/" '{print $6}')
ACTUAL_VERSION=$(jq -rc '.version' /usr/share/discord/resources/build_info.json)
if [[ ${ACTUAL_VERSION} != ${LATEST_VERSION} ]]; then
    echo "Versões diferentes"
    sudo sed -i 's/'${ACTUAL_VERSION}'/'${LATEST_VERSION}'/g' /usr/share/discord/resources/build_info.json
else echo "Versões iguais"; fi