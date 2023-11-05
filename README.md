# d4099fef0beb59b6
**證書申請脚本來自[@FranzKafkaYu](https://github.com/FranzKafkaYu/x-ui/blob/main/x-ui.sh)，安裝脚本來自[@XTLS](https://github.com/XTLS/Xray-install)**

**僅在Ubuntu上運行xray_script**

協議類型: vms+tcp+tls

數量:1

**使用條件:**

付費域名
    
由Cloudfare解析
    
Cloudflare Global API Key
    
Coloudfare注冊郵箱


**安裝curl**
```
apt install curl
```

**下載**
```
curl -X GET -H 'Cache-Control: no-cache' -O https://raw.githubusercontent.com/yoier/d4099fef0beb59b6/main/script.sh
```

**直接使用**
```
bash <(curl -Ls https://raw.githubusercontent.com/yoier/d4099fef0beb59b6/main/script.sh)
```

**執行**
```
bash script.sh
```

**相關目錄**

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

acme證書: cert_path:/root/cert

**相關指令**

**xy_command:**

啓動
```
xray run -c /usr/local/etc/xray/*.json
```
自啓動
```
systemctl start xray.service
```
重啓
```
systemctl restart xray.service
```
運行狀態
```
systemctl status xray.service
```
删除证书
```
~/.acme.sh/acme.sh --remove -d example.com
```
