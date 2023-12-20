#!/bin/bash

admin_id=$(sed -n '2p' /root/databot.txt)
TOKEN=$(sed -n '1p' /root/databot.txt)
BASE_URL="https://api.telegram.org/bot$TOKEN"

main_keyboard='[[ {"text": "Check IP", "callback_data": "check_ip"}, {"text": "Passwall Switch", "callback_data": "passwall"} ],[{"text": "Connected Devices", "callback_data": "devices"},{"text": "Check IMEI", "callback_data": "check_imei"}],[{"text": "Modem Details", "callback_data": "details"}],[{"text": "Reboot", "callback_data": "reboot"}] ]'

chat_id=""
message_id=""
offset=0
timeout=30

send_message() {
    local text="$1"
    curl -s -X POST "$BASE_URL/sendMessage" -d "chat_id=$chat_id&text=$text&parse_mode=HTML" >/dev/null
}

send_inline_keyboard() {
    local text="$1"
    local keyboard="$2"
    local update="$3"
    if [ "$update" == "" ]; then
        curl -s -X POST "$BASE_URL/sendMessage" -d "chat_id=$chat_id&text=$text&parse_mode=html&reply_markup={\"inline_keyboard\":$keyboard}" >/dev/null
    else
        curl -s -X POST "$BASE_URL/editMessageText" -d "chat_id=$chat_id&message_id=$update&text=$text&parse_mode=html&reply_markup={\"inline_keyboard\":$keyboard}" >/dev/null
    fi
}

handle_message() {
    local message="$1"

    case $message in
    "/start")
        chat_id=$(echo "$updates" | jq -r ".result[0].message.chat.id")
        send_inline_keyboard "Welcome! Choose an option:" "$main_keyboard"
        ;;
    "/help")
        send_message "This is a simple bot. Use /start to begin."
        ;;
    "/checkip")
        local ip_modem=$(curl -s "https://ipv4.icanhazip.com")
        local response="Your external IP address is: $ip_modem"
        send_message "$response"
        ;;
    "/reboot")
        send_message "Rebooting... (Just kidding!)"
        ;;
    #*)
    #    send_message "Type /start to see available options."
    #    ;;
    esac
}

handle_callback_query() {
    local callback_data="$1"
    local callback_message_message_id="$2"

    case $callback_data in
    "check_ip")
        local ip_modem=$(curl -s "https://ipv4.icanhazip.com")
        local response="Your external IP address is: $ip_modem"
        keyboard='[[{"text": "Main Menu", "callback_data": "start"}] ]'
        send_inline_keyboard "$response" "$keyboard" "$callback_message_message_id"
        ;;
    "reboot")
        send_message "Rebooting..."
        reboot
        ;;
    "details")
        keyboard='[[{"text": "Main Menu", "callback_data": "start"}] ]'
        send_inline_keyboard "Soon" "$keyboard" "$callback_message_message_id"
        ;;
    "devices")
        ips=$(cat /proc/net/arp | grep -v "incomplete" | awk '{print $1}')
        devices_data="Devices Connected%0A"
        for ip in $(echo "$ips"); do
            devices_data+=$(nslookup $ip | grep -o 'name = [^.]*' | grep -o '[^ ]*$')
            devices_data+="%0A"
        done
        keyboard='[[{"text": "Main Menu", "callback_data": "start"}] ]'
        send_inline_keyboard "$devices_data" "$keyboard" "$callback_message_message_id"
        ;;
    "passwall")
        stat=$(/etc/init.d/passwall status)
        if [ -z $stat]; then
            stat="Not installed"
        else
            if [ "$(echo "$stat" | grep -wc "running")" != "0" ]; then
                /etc/init.d/passwall stop
            else
                /etc/init.d/passwall start
            fi
            stat=$(/etc/init.d/passwall status)
        fi
        keyboard='[[{"text": "Main Menu", "callback_data": "start"}] ]'
        send_inline_keyboard "Passwall Status : $stat" "$keyboard" "$callback_message_message_id"
        ;;
    "check_imei")
        imei=$(uci show modem | grep -o "imei='[^']*" | grep -o "[^']*$")
        keyboard='[[{"text": "Main Menu", "callback_data": "start"}] ]'
        send_inline_keyboard "Imei : $imei" "$keyboard" "$callback_message_message_id"
        ;;
    "start")
        send_inline_keyboard "Welcome! Choose an option:" "$main_keyboard" "$callback_message_message_id"
        ;;
    esac
}

while true; do
    updates=$(curl -s "$BASE_URL/getUpdates?offset=$offset&timeout=$timeout")

    callback_data=$(echo "$updates" | jq -r ".result[0].callback_query.data")
    callback_message_message_id=$(echo "$updates" | jq -r ".result[0].callback_query.message.message_id")
    message_id=$(echo "$updates" | jq -r ".result[0].update_id")
    message=$(echo "$updates" | jq -r ".result[0].message.text")
    from_id=$(echo "$updates" | jq -r ".result[0].message.from.id")
    if [ "$from_id" == "null" ]; then
        from_id=$(echo "$updates" | jq -r ".result[0].callback_query.from.id")
    fi
    if [ "$from_id" == "$admin_id" ]; then
        if [ "$message" != "null" ]; then
            handle_message "$message"
        fi

        if [ "$callback_data" != "null" ]; then
            handle_callback_query "$callback_data" "$callback_message_message_id"
        fi
    fi
    offset=$((message_id + 1))
done
