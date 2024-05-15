#!/bin/bash
clear

read -p "Bot token : " token
read -p "Admin Id  : " admin_id
echo "$token" >/root/databot.txt
echo "$admin_id" >>/root/databot.txt

opkg update
opkg install jq --force-depends
opkg install screen --force-depends

curl -s "https://raw.githubusercontent.com/syfqsamvpn/openwrt_bot/main/openwrt.sh" >/root/bot_tele.sh
chmod +x /root/bot_tele.sh

screen -dmS bot_sam /root/bot_tele.sh
sed -i '$ i\screen -dmS bot_sam /root/bot_tele.sh' /etc/rc.local >/dev/null 2>&1
