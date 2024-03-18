#!/bin/bash
#on ubuntu
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
[[ $EUID -ne 0 ]] && LOGE "Error:  Must use root!\n" && exit 1
confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}
install_acme() {
    cd ~
    LOGI $text36
    apt update
    apt install cron socat net-tools ufw unzip diffutils
    LOGI $text30
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        return 1
    fi
    return 0
}
ssl_cert_issue_by_cloudflare() {
    echo -E ""
    LOGD $text17
    LOGI $text18
    LOGI $text19
    LOGI $text20
    LOGI $text21
    LOGI $text22
    confirm "$text23" "y"
    if [ $? -eq 0 ]; then
        install_acme
        if [ $? -ne 0 ]; then
            LOGE $text24
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        fi
        LOGD $text25
        read CF_Domain
        LOGD $text26
        #here we need to judge whether there exists cert already
        local currentCert=$(~/.acme.sh/acme.sh --list | grep ${CF_Domain} | wc -l)
        if [ ${currentCert} -ne 0 ]; then
            local certInfo=$(~/.acme.sh/acme.sh --list)
            LOGE $text27
            LOGI "$certInfo"
            exit 1
        else
            LOGI $text28
        fi
        LOGD $text29
        read CF_GlobalKey
        LOGD $text31
        read CF_AccountEmail
        LOGD $text32
	cf_cer_pth="$certPath/${CF_Domain}.crt"
        cf_key_pth="$certPath/${CF_Domain}.key"
        LOGI "\t$CF_Domain\n\t$CF_GlobalKey\n\t$CF_AccountEmail"
        confirm "$text44" "y"
        if [ $? -eq 0 ]; then
            echo "$text45"
        else
            exit 0
        fi
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE $text33
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE $text34
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI $text35
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} --ca-file /root/cert/ca.crt \
            --cert-file /root/cert/server.crt --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/${CF_Domain}.crt
        if [ $? -ne 0 ]; then
            LOGE $text34
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
	    cp $cf_cer_pth $cf_cer_pth.bak
            LOGI $text37
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE $text38
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI $text39
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        exit 0
    fi
}
get_ip() {
    eth=`ifconfig | grep -Eo ".*: " | grep -Eo "\w*" | grep -v lo`
    ip=`ifconfig $eth| grep -Eo "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -Eo "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"`
    ethnum=`ifconfig | grep -Eo ".*: " | grep -Eo "\w*" | grep -v -c lo`
    ethnum=$((ethnum))
    LOGD ${text40}$ip
    #echo $ethnum
    #echo -e "all_ipaddress:\n"$ip
    use_ip=""
    if [ $ethnum != 1 ];then
            LOGD $text41
            read use_ip
    else
            use_ip=$ip
    fi
}
xray_config() {
    get_ip
    cf_ip=${use_ip}
    cf_port=""
    cf_name=""
    cf_uuid=`xray uuid`
    cf_don=${CF_Domain}
    LOGD $text42
    read cf_name
    LOGD $text43
    read cf_port
    #443 port only
    LOGD "------------"
    LOGD "\tname:$cf_name\n\tip:$cf_ip\n\tport:$cf_port\n\tuuid:$cf_uuid\n\tdon:$cf_don\n\tcer_pth:$cf_cer_pth\n\tkey_pth:$cf_key_pth"
    LOGD "------------"
    confirm "$text44" "y"
        if [ $? -eq 0 ]; then
            echo "$text45"
        else
            exit 0
        fi
    cat >/usr/local/etc/xray/config.json<<EOF
{
    "log": null,
    "routing": {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "dns": null,
    "inbounds": [
        {
            "listen": "$cf_ip",
            "port": $cf_port,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$cf_uuid",
                        "level": 0
                    }
                ],
                "disableInsecureEncryption": false
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "$cf_don",
                    "certificates": [
                        {
                            "certificateFile": "$cf_cer_pth",
                            "keyFile": "$cf_key_pth"
                        }
                    ]
                },
                "tcpSettings": {
                    "header": {
                        "type": "none"
                    }
                }
            },
            "tag": "inbound-$cf_port",
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    echo -e "-----------------------------------------------"
    echo -e "vmess://$cf_uuid@$cf_don:$cf_port?headerType=none&type=tcp&security=tls&sni=$cf_don&allowInsecure#$cf_name\n" > /usr/link.vmss
    echo -e "----------your_link_pth:/usr/link.vmss----------"
    cat /usr/link.vmss
}
nginx_config() {
    apt install nginx
    cd /root
    mkdir site_back
    mkdir mv_tmp
    cd mv_tmp
    curl -JLo html.zip https://github.com/yoier/d4099fef0beb59b6/archive/refs/tags/rls.zip
    unzip html.zip
    cd d4099fef0beb59b6*
    mv -f /var/www/html/* /root/site_tp
    mv -f html/* /var/www/html
    cd /root
    rm -rf mv_tmp
    #可更换mv内容html
    ls /var/www/html
    confirm "$text44" "y"
        if [ $? -eq 0 ]; then
            echo "$text45"
        else
            exit 0
        fi
    cat >/etc/nginx/sites-available/default<<EOF
server {
    listen 80 default_server;
    server_name $cf_don;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
     #HTTPS的默认访问端口443。
     #如果未在此处配置HTTPS的默认访问端口，可能会造成Nginx无法启动。
     listen 443 ssl;
     
     #填写证书绑定的域名
     server_name $cf_don;
 
     #填写证书文件名称
     ssl_certificate $cf_cer_pth;
     #填写证书私钥文件名称
     ssl_certificate_key $cf_key_pth;
 
     ssl_session_cache shared:SSL:1m;
     ssl_session_timeout 5m;
	 
     #自定义设置使用的TLS协议的类型以及加密套件（以下为配置示例，请您自行评估是否需要配置）
     #TLS协议版本越高，HTTPS通信的安全性越高，但是相较于低版本TLS协议，高版本TLS协议对浏览器的兼容性较差。
     ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
     ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

     #表示优先使用服务端加密套件。默认开启
     ssl_prefer_server_ciphers on;
 
 
    location / {
           root /var/www/html;
           index index.html index.htm;
    }
}
EOF
}
auto_update_config() {
cat >/usr/juje.sh<<EOF
diff $cf_cer_pth $cf_cer_pth.bak
if [ \$? -eq 0 ]; then
echo "do not update."
bash -c "\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
exit 0
else
cp $cf_cer_pth $cf_cer_pth.bak
bash -c "\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root|grep "No new version"
if [ \$? -eq 0 ]; then
systemctl restart xray.service
echo "restart."
exit 0
else
echo "update success!"
echo "do not restart."
fi
fi
EOF
chmod 777 /usr/juje.sh
cat >/usr/ctm.txt<<EOF
0 4 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null
10 4 * * * /usr/juje.sh > /dev/null

EOF
crontab -u root /usr/ctm.txt
}
all_txt() {
    if [ $1 -eq 1 ]; then
        text0="\t0.exit\n\t1.install_all\n\t2.install&&upgrade_xary_use_root\n\t3.get_cf_crt\n\t4.xray_filepth\n\t5.stop_xray\n\t6.restart_xary\n\t7.start_xary\n\t8.update_geop\n\t9.remove_xary"
        text1="Exit script..."
        text2="Apply for a certificate"
        text3="Install or Upgrade_xray"
        text4="xray install_path\n\tinstalled: /etc/systemd/system/xray.service\n\tinstalled: /etc/systemd/system/xray@.service\n\tinstalled: /usr/local/bin/xray\n\tinstalled: /usr/local/etc/xray/*.json\n\tinstalled: /usr/local/share/xray/geoip.dat\n\tinstalled: /usr/local/share/xray/geosite.dat\n\tinstalled: /var/log/xray/access.log\n\tinstalled: /var/log/xray/error.log\nlink and cert files\n\tlink_path:/usr/link.vls\n\tcert_path:/root/cert\n\tupdatetmp:/usr/ctm.txt\n\tupdatejuje:/usr/juje.sh\nsome_command: \n\txray run -c /usr/local/etc/xray/*.json\n\tsystemctl start xray.service\n\tsystemctl status xray.service\n\tnginx -s reload"
        text5="Success(y) or failure(n)[y/n]"
        text6="Xray install success"
        text7="Restart xray"
        text8="Start xray"
        text9="Stop xray"
        text10="Upgrade geop"
        text11="Remove xray"
        text12="Remaind cfg.json and logs?[y/n]"
        text13="Removed xray-corn only"
        text14="Apply certificate success"
        text15="Unknown number and Exit script"
        text16="Menu"
        text17="******Instructions******"
        text18="This scripts use Acme to apply certificate,you should known:"
        text19="1.Cloudflare register e-mail"
        text20="2.Cloudflare Global API Key"
        text21="3.Domain names are resolved through the Cloudflare"
        text22="4.Install path with: /root/cert"
        text23="I have confirmed the above[y/n]"
        text24="Unable to install acme,please check the error log"
        text25="Please set domain name:"
        text26="Verifying..."
        text27="Verification failed,Duplicate domain name,Certificate status:"
        text28="Verification passed..."
        text29="Please set API Key:"
        text30="Dependency installation completed"
        text31="Please set your register e-mail:"
        text32="Check information:"
        text33="Revise CA to Lets'Encrypt fail,Script exit"
        text34="Certificate issuance failed,Script exit"
        text35="Certificate issuance success,installing..."
        text36="Install dependencies and acme script..."
        text37="Certificate install success,Turn on automatic updates..."
        text38="Automatic update settings failed,Script exit"
        text39="Certificate install success and Turn on automatic updates,information:"
        text40="Check ip:"
        text41="Set your ip:"
        text42="Set node name:"
        text43="Set node port:"
        text44="Confirm configuration is correct[y/n]"
        text45="Start writing..."

    else
        text0="\t0.退出\n\t1.安装并配置全部\n\t2.安装或更新Xray\n\t3.获取cloud证书\n\t4.相关安装文件路径\n\t5.停止Xray\n\t6.重启Xray\n\t7.启动Xray\n\t8.更新geop规则\n\t9.卸载Xray"
        text1="脚本已退出..."
        text2="申请证书"
        text3="安装或更新Xray"
        text4="Xray安装路径\n\tinstalled: /etc/systemd/system/xray.service\n\tinstalled: /etc/systemd/system/xray@.service\n\tinstalled: /usr/local/bin/xray\n\tinstalled: /usr/local/etc/xray/*.json\n\tinstalled: /usr/local/share/xray/geoip.dat\n\tinstalled: /usr/local/share/xray/geosite.dat\n\tinstalled: /var/log/xray/access.log\n\tinstalled: /var/log/xray/error.log\n链接及证书路径\n\tlink_path:/usr/link.vls\n\tcert_path:/root/cert\n\tupdatetmp:/usr/ctm.txt\n\tupdatejuje:/usr/juje.sh\n相关命令: \n\txray run -c /usr/local/etc/xray/*.json\n\tsystemctl start xray.service\n\tsystemctl status xray.service\n\tnginx -s reload"
        text5="成功(y) 还是 失败(n)[y/n]"
        text6="Xray安装成功"
        text7="重启Xray"
        text8="启动Xray"
        text9="停止Xray"
        text10="更新geop规则"
        text11="已移除Xray所有内容"
        text12="是否保留配置文件及日志?[y/n]"
        text13="仅卸载了Xray内核,保留了json及logs"
        text14="证书申请成功"
        text15="未知的数字,退出脚本..."
        text16="菜单"
        text17="******使用说明******"
        text18="该脚本将使用Acme脚本申请证书,使用时需保证:"
        text19="1.知晓Cloudflare 注册邮箱"
        text20="2.知晓Cloudflare Global API Key"
        text21="3.域名已通过Cloudflare进行解析到当前服务器"
        text22="4.该脚本申请证书默认安装路径为/root/cert目录"
        text23="我已确认以上内容[y/n]"
        text24="无法安装acme,请检查错误日志"
        text25="请设置域名:"
        text26="正在进行域名合法性校验..."
        text27="域名合法性校验失败,当前环境已有对应域名证书,不可重复申请,当前证书详情:"
        text28="域名合法性校验通过..."
        text29="请设置API密钥:"
        text30="依赖安装成功"
        text31="请设置注册邮箱:"
        text32="核对你的输入信息:"
        text33="修改默认CA为Lets'Encrypt失败,脚本退出"
        text34="证书签发失败,脚本退出"
        text35="证书签发成功,安装中..."
        text36="开始安装相关依赖及acme脚本..."
        text37="证书安装成功,开启自动更新..."
        text38="自动更新设置失败,脚本退出"
        text39="证书已安装且已开启自动更新,具体信息如下"
        text40="检测到的ip地址:"
        text41="手动输入ip地址:"
        text42="设置节点名称:"
        text43="设置节点端口:"
        text44="确认配置无误[y/n]"
        text45="开始写入..."
    fi
}
language() {
    LOGI "Language"
    echo -e "\t1.English\n\t2.简体中文"
    read num0
    case "${num0}" in
    1)
        all_txt 1;;
    2)
        all_txt 2;;
    *)
        LOGE "Unknown number and Exit script"
        exit 0;;
    esac
}
menu() {
    LOGI $text16
    echo -e $text0 && read num
    case "${num}" in
    0)
        LOGI $text1
        exit
        ;;
    1)
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
        confirm "$text5" "y"
        if [ $? -eq 0 ]; then
            LOGI $text6
        else
            exit
        fi
        LOGD $text2
        ssl_cert_issue_by_cloudflare
        LOGI $text14
        xray_config
        #nginx..
        nginx_config
	      auto_update_config
	      ufw enable
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow $cf_port/tcp
        ufw reload
        nginx -s reload
        systemctl restart xray.service
        LOGI $text7
        cat /usr/link.vmss
        ;;
    2)
        LOGI $text3
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
        LOGI $text6
        ;;
    3)
        LOGI $text2
        ssl_cert_issue_by_cloudflare
        ;;
    4)
        echo -e $text4
        ;;
    5)
        systemctl stop xray.service
        LOGI $text9
        ;;
    6)
        systemctl restart xray.service
        LOGI $text7
        ;;
    7)
        systemctl start xray.service
        LOGI $text8
        ;;
    8)
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata
        LOGI $text10
        ;;
    9)
        confirm "$text12" "y"
        if [ $? -eq 0 ]; then
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
            LOGI $text13
        else
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
            LOGI $text11
        fi
        ;;
    *)
        LOGE $text15
        exit
        ;;
    esac
    menu
}
main() {
    language
    menu
}
main
