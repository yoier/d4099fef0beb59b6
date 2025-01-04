#!/bin/bash
apt update
apt install cron ufw
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
echo "continue?(y(default)/n)"
read ctu
if [[ ctu == "n" ]];then
exit 0
fi
echo "input ip"
read ip
echo "input port"
read port
cat >/usr/local/etc/xray/config.json<<EOF
{
    "inbounds": [
        {
            "listen": "$ip",
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "network": "tcp,udp",
                "method": "2022-blake3-aes-128-gcm",
                "password": "$(openssl rand -base64 16)"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
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
(crontab -l; echo '0 6 * * 1 bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root) | crontab -
crontab -l
fi
cat /usr/local/etc/xray/config.json
exit 0