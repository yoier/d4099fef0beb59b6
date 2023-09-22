# d4099fef0beb59b6
**證書申請脚本來自[@FranzKafkaYu](https://github.com/FranzKafkaYu/x-ui/blob/main/x-ui.sh)**

**僅在Ubuntu上運行
協議類型: vms+tcp+tls
數量:1
使用條件: 
    付費域名
    由Cloudfare解析
    Cloudflare Global API Key
    Coloudfare注冊郵箱**

**下載並使用**
```
bash <(curl -Ls https://raw.githubusercontent.com/yoier/d4099fef0beb59b6/main/script.sh)
```

**下載**
```
curl -O https://raw.githubusercontent.com/yoier/d4099fef0beb59b6/main/script.sh
```

**執行**
```
bash script.sh
```

**相關目錄
install_path
installed: /etc/systemd/system/xray.service
installed: /etc/systemd/system/xray@.service
installed: /usr/local/bin/xray
installed: /usr/local/etc/xray/*.json
installed: /usr/local/share/xray/geoip.dat
installed: /usr/local/share/xray/geosite.dat
installed: /var/log/xray/access.log
installed: /var/log/xray/error.log

vmess鏈接: link_path:/usr/link.vms
acme證書: cert_path:/root/cert**

**相關指令
xy_command: **
```
xray run -c /usr/local/etc/xray/*.json
systemctl start xray.service
systemctl status xray.service
```
