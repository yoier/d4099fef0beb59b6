#!/bin/bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
apt update
apt install cron ufw
echo "input ip"
read ip
echo "input port"
read port
echo "input psk"
read psk
cat >/usr/local/etc/xray/config.json<<EOF
{
    "log": null,
    "inbounds": [
        {
            "listen": "$ip",
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "network": "tcp,udp",
                "method": "2022-blake3-aes-128-gcm",
                "password": "$psk"
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
ufw enable
ufw allow $port
ufw reload
systemctl restart xray.service
echo "auto update?[y/n]"
read x1
if [[ $x1 == "y" ]];then
(crontab -l; echo '0 6 * * 1 bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install') | crontab -
crontab -l
fi
