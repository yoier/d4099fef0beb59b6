#!/bin/bash
#on ubuntu
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
[[ $EUID -ne 0 ]] && LOGE "错误:  必须使用root用户运行此脚本!\n" && exit 1
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
get_ip() {
    eth=`ifconfig | grep -Eo ".*: " | grep -Eo "\w*" | grep -v lo`
    ip=`ifconfig $eth| grep -Eo "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -Eo "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*"`
    ethnum=`ifconfig | grep -Eo ".*: " | grep -Eo "\w*" | grep -v -c lo`
    ethnum=$((ethnum))
    echo $ip
    echo $ethnum
    echo -e "all_ipaddress:\n"$ip
    use_ip=""
    if [ $ethnum != 1 ];then
            read -p "Input your vps_ip here:" use_ip
    else
            use_ip=$ip
    fi
}
cof_json() {
    get_ip
    cf_ip=${use_ip}
    cf_port=""
    cf_name=""
    cf_uuid=`xray uuid`
    cf_don=${CF_Domain}
    cf_cer_pth="$certPath/${CF_Domain}.cer"
    cf_key_pth="$certPath/${CF_Domain}.key"
    read -p "Set your xy_name:" cf_name
    read -p "Input your xy_port:" cf_port
    echo -e "This is ur cfg:
    name:$cf_name
    ip:$cf_ip
    port:$cf_port
    uuid:$cf_uuid
    don:$cf_don
    cer_pth:$cf_cer_pth
    key_pth:$cf_key_pth
    "
    confirm "确认配置無誤[y/n]" "y"
        if [ $? -eq 0 ]; then
            echo "開始寫入config"
        else
            exit 0
        fi
    echo "{
    \"log\": null,
    \"routing\": {
        \"domainStrategy\": \"AsIs\",
        \"rules\": [
            {
                \"type\": \"field\",
                \"ip\": [
                    \"geoip:private\"
                ],
                \"outboundTag\": \"block\"
            },
            {
                \"type\": \"field\",
                \"protocol\": [
                    \"bittorrent\"
                ],
                \"outboundTag\": \"block\"
            }
        ]
    },
    \"dns\": null,
    \"inbounds\": [
        {
            \"listen\": \"$cf_ip\",
            \"port\": $cf_port,
            \"protocol\": \"vmess\",
            \"settings\": {
                \"clients\": [
                    {
                        \"id\": \"$cf_uuid\",
                        \"alterId\": 0
                    }
                ],
                \"disableInsecureEncryption\": false
            },
            \"streamSettings\": {
                \"network\": \"tcp\",
                \"security\": \"tls\",
                \"tlsSettings\": {
                    \"serverName\": \"$cf_don\",
                    \"certificates\": [
                        {
                            \"certificateFile\": \"$cf_cer_pth\",
                            \"keyFile\": \"$cf_key_pth\"
                        }
                    ]
                },
                \"tcpSettings\": {
                    \"header\": {
                        \"type\": \"none\"
                    }
                }
            },
            \"tag\": \"inbound-$cf_port\",
            \"sniffing\": {
                \"enabled\": true,
                \"destOverride\": [
                    \"http\",
                    \"tls\"
                ]
            }
        }
    ],
    \"outbounds\": [
        {
            \"protocol\": \"freedom\",
            \"tag\": \"direct\"
        },
        {
            \"protocol\": \"blackhole\",
            \"tag\": \"block\"
        }
    ]
}">/usr/local/etc/xray/config.json
    base64_link=`echo -n "{
  \"v\": \"2\",
  \"ps\": \"$cf_name\",
  \"add\": \"$cf_don\",
  \"port\": $cf_port,
  \"id\": \"$cf_uuid\",
  \"aid\": 0,
  \"net\": \"tcp\",
  \"type\": \"none\",
  \"host\": \"\",
  \"path\": \"\",
  \"tls\": \"tls\"
}" | base64 |tr -d '\n'`
    echo -e "vmess://$base64_link\n" > /usr/link.vms
    echo -e "----------\nyour_link_pth:/usr/link.vms\n----------"
    cat /usr/link.vms
}
install_acme() {
    cd ~
    LOGI "开始安装acme脚本..."
    apt update
    apt install cron socat net-tools
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "acme安装失败"
        return 1
    else
        LOGI "acme安装成功"
    fi
    return 0
}
ssl_cert_issue_by_cloudflare() {
    echo -E ""
    LOGD "******使用说明******"
    LOGI "该脚本将使用Acme脚本申请证书,使用时需保证:"
    LOGI "1.知晓Cloudflare 注册邮箱"
    LOGI "2.知晓Cloudflare Global API Key"
    LOGI "3.域名已通过Cloudflare进行解析到当前服务器"
    LOGI "4.该脚本申请证书默认安装路径为/root/cert目录"
    confirm "我已确认以上内容[y/n]" "y"
    if [ $? -eq 0 ]; then
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "无法安装acme,请检查错误日志"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        fi
        LOGD "请设置域名:"
        read -p "Input your domain here:" CF_Domain
        LOGD "你的域名设置为:${CF_Domain},正在进行域名合法性校验..."
        #here we need to judge whether there exists cert already
        local currentCert=$(~/.acme.sh/acme.sh --list | grep ${CF_Domain} | wc -l)
        if [ ${currentCert} -ne 0 ]; then
            local certInfo=$(~/.acme.sh/acme.sh --list)
            LOGE "域名合法性校验失败,当前环境已有对应域名证书,不可重复申请,当前证书详情:"
            LOGI "$certInfo"
            exit 1
        else
            LOGI "域名合法性校验通过..."
        fi
        LOGD "请设置API密钥:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "你的API密钥为:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "你的注册邮箱为:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "修改默认CA为Lets'Encrypt失败,脚本退出"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书签发失败,脚本退出"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "证书签发成功,安装中..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "证书安装失败,脚本退出"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            LOGI "证书安装成功,开启自动更新..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "自动更新设置失败,脚本退出"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "证书已安装且已开启自动更新,具体信息如下"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        exit 0
    fi
}
main() {
    echo && read -p "
    0.exit
    1.get_cf_crt
    2.install&&upgrade_xy_use_root
    3.xy_filepth
    4.install_all
    5.stop_xy
    6.restart_xy
    7.start_xy
    8.update_geop
    9.remove_xy
    " num
    case "${num}" in
    0)
        exit
        ;;
    1)
        ssl_cert_issue_by_cloudflare
        ;;
    2)
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
        ;;
    3)
        echo "
    install_path
    installed: /etc/systemd/system/xray.service
    installed: /etc/systemd/system/xray@.service
    installed: /usr/local/bin/xray
    installed: /usr/local/etc/xray/*.json
    installed: /usr/local/share/xray/geoip.dat
    installed: /usr/local/share/xray/geosite.dat
    installed: /var/log/xray/access.log
    installed: /var/log/xray/error.log
    
    link_path:/usr/link.vms
    cert_path:/root/cert
    
    xy_command: 
    xray run -c /usr/local/etc/xray/*.json
    systemctl start xray.service
    systemctl status xray.service
"
        ;;
    4)
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
        confirm "确认xray安裝成功,準備申請cloudfare證書[y/n]" "y"
        if [ $? -eq 0 ]; then
            echo "xray安裝成功，開始申請cloudfare證書"
        else
            exit
        fi
        ssl_cert_issue_by_cloudflare
        confirm "确认證書安裝成功，準備配置cfg[y/n]" "y"
        if [ $? -eq 0 ]; then
            echo "證書申請成功，開始配置config"
        else
            exit
        fi
        cof_json
        confirm "确认配置成功，準備重啓xy" "y"
        if [ $? -eq 0 ]; then
            echo "重啓xy"
        else
            exit
        fi
        systemctl restart xray.service
        echo "xy restart"
        ;;
    5)
        systemctl stop xray.service
        echo "xy stop"
        ;;
    6)
        systemctl restart xray.service
        echo "xy restart"
        ;;
    7)
        systemctl start xray.service
        echo "xy start"
        ;;
    8)
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata
        echo "upgrade_geodat"
        ;;
    9)
        echo && read -p "remaind cfg.json and log?
        1.remaind
        2.don't remaind
        " num2
        case "${num2}" in
        1)
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
            echo "only remove x_corn"
            ;;
        2)
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
            echo "remove all"
            ;;
        *)
            echo "err num"
            exit
            ;;
        esac
        ;;
    *)
        LOGE "err num"
        exit
        ;;
    esac
    main
}
main
