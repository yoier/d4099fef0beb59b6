#!/bin/bash
apt update
echo "install ufw?(n(default)/y)"
read uw
if [[ uw == "y" ]];then
apt install ufw
fi
apt install cron
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
if [[ uw == "y" ]];then
ufw enable
ufw allow $port
ufw reload
fi
systemctl restart xray.service
echo "auto update?[y/n]"
read x1
if [[ $x1 == "y" ]];then
if [ -e "/usr/local/share/upgd.sh" ]; then
    echo "has cof"
else
    echo "config..."
    cat >/usr/local/share/upgd.sh<<EOF
#!/bin/bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
EOF
chmod +x /usr/local/share/upgd.sh
(crontab -l; echo "0 5 * * 2 /usr/local/share/upgd.sh") | crontab -
crontab -l
fi
fi
cat /usr/local/etc/xray/config.json
exit 0