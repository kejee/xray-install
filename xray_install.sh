#!/bin/bash

CONFIG_FILE="/etc/xray/config.json"

# 检查是否有 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "请以 root 身份运行此脚本。"
    exit 1
fi

# 安装Xray
install_xray() {
    echo "更新系统并安装必要的工具..."
    apt update && apt install -y unzip curl uuid-runtime jq

    echo "正在下载 Xray-core..."
    cd /tmp
    curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    unzip xray.zip -d xray
    mv xray/xray /usr/local/bin/
    rm -rf /tmp/xray /tmp/xray.zip

    # 创建配置文件夹
    mkdir -p /etc/xray

    # 用户交互获取端口和 UUID
    read -p "请输入 Xray 服务监听的端口 (默认: 1080): " port
    port=${port:-1080}
    uuid=$(uuidgen)
    echo "生成的 UUID 为: $uuid"
    read -p "是否启用 WebSocket (y/n, 默认: n): " use_ws
    use_ws=${use_ws:-n}
    if [[ $use_ws == "y" ]]; then
        read -p "请输入 WebSocket 路径 (默认: /websocket): " ws_path
        ws_path=${ws_path:-/websocket}
    fi
    read -p "是否启用 TLS 加密 (y/n, 默认: n): " use_tls
    use_tls=${use_tls:-n}
    if [[ $use_tls == "y" ]]; then
        read -p "请输入 TLS 域名: " tls_domain
        read -p "请输入 TLS 证书文件路径: " tls_cert
        read -p "请输入 TLS 私钥文件路径: " tls_key
    fi

    # 创建 Xray 配置文件
    cat <<EOF > $CONFIG_FILE
{
  "inbounds": [{
    "port": $port,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "alterId": 0
        }
      ]
    },
    "streamSettings": {
      "network": "$(if [[ $use_ws == "y" ]]; then echo "ws"; else echo "tcp"; fi)"
      $(if [[ $use_ws == "y" ]]; then
        echo ",\"wsSettings\": {\"path\": \"$ws_path\"}"
      fi)
      $(if [[ $use_tls == "y" ]]; then
        echo ",\"security\": \"tls\","
        echo "\"tlsSettings\": {\"certificates\": [{\"certificateFile\": \"$tls_cert\", \"keyFile\": \"$tls_key\"}]}"
      fi)
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF

    # 设置 Systemd 服务
    cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 启动并启用 Xray 服务
    echo "启动 Xray 服务..."
    systemctl daemon-reload
    systemctl start xray
    systemctl enable xray

    # 显示配置信息
    echo
    echo "Xray-core 已安装并配置完成。"
    echo "--------------------------------"
    echo "地址: $(curl -s ifconfig.me)"
    echo "端口: $port"
    echo "UUID: $uuid"
    if [[ $use_ws == "y" ]]; then
        echo "WebSocket 路径: $ws_path"
    fi
    if [[ $use_tls == "y" ]]; then
        echo "TLS 域名: $tls_domain"
        echo "TLS 证书路径: $tls_cert"
        echo "TLS 私钥路径: $tls_key"
    fi
    echo "--------------------------------"
}

# 卸载Xray
uninstall_xray() {
    systemctl stop xray
    systemctl disable xray
    rm -f /usr/local/bin/xray
    rm -rf /etc/xray
    rm -f /etc/systemd/system/xray.service
    systemctl daemon-reload
    echo "Xray 卸载完成！"
}

# 修改端口
modify_port() {
    read -p "请输入新的端口号: " new_port
    sed -i "s/\"port\": [0-9]\+/\"port\": $new_port/" $CONFIG_FILE
    systemctl restart xray
    echo "端口已修改为 $new_port，并重启 Xray 服务。"
}

# 修改UUID
modify_uuid() {
    new_uuid=$(uuidgen)
    sed -i "s/\"id\": \".*\"/\"id\": \"$new_uuid\"/" $CONFIG_FILE
    systemctl restart xray
    echo "UUID 已修改为 $new_uuid，并重启 Xray 服务。"
}

# 查看配置信息
view_config() {
    cat $CONFIG_FILE
}
# 查看 Xray 配置信息
view_config_plus() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Xray 配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    port=$(jq '.inbounds[0].port' "$CONFIG_FILE")
    uuid=$(jq -r '.inbounds[0].settings.clients[0].id' "$CONFIG_FILE")
    ip=$(curl -s ifconfig.me)

    echo "Xray 服务配置信息："
    echo "--------------------------------"
    echo "服务器 IP 地址: $ip"
    echo "端口号: $port"
    echo "UUID: $uuid"

    # WebSocket 配置
    use_ws=$(jq -r '.inbounds[0].streamSettings.network' "$CONFIG_FILE")
    if [[ "$use_ws" == "ws" ]]; then
        ws_path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' "$config_file")
        echo "WebSocket 路径: $ws_path"
    fi

    # TLS 配置
    use_tls=$(jq -r '.inbounds[0].streamSettings.security' "$CONFIG_FILE")
    if [[ "$use_tls" == "tls" ]]; then
        tls_cert=$(jq -r '.inbounds[0].streamSettings.tlsSettings.certificates[0].certificateFile' "$CONFIG_FILE")
        tls_key=$(jq -r '.inbounds[0].streamSettings.tlsSettings.certificates[0].keyFile' "$CONFIG_FILE")
        echo "TLS 证书文件: $tls_cert"
        echo "TLS 私钥文件: $tls_key"
    fi
    echo "--------------------------------"
}

# 查看Xray实时日志
view_realtime_logs() {
    sudo journalctl -u xray -f
}

# 查看连接的客户端
view_connections() {
    # 检查配置文件是否存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    # 从配置文件中读取端口号
    port=$(jq -r '.inbounds[0].port' "$CONFIG_FILE")

    # 检查端口是否成功提取
    if [[ -z "$port" ]]; then
        echo "未能从配置文件中提取端口号"
        exit 1
    fi

    # 输出提取的端口号
    echo "从配置文件中读取到端口号: $port"

    # 执行 ss 命令并分析结果
    echo "原始结果："
    ss -atn | grep ":${port}"
    echo
    echo "整理后的结果："
    # 通过 awk 提取客户端 IP，去除 IPv6 地址中的 IPv4 地址部分，统计每个客户端的连接数
    ss -atn | grep ":${port}" | awk '{print $5}' | sed -E 's/\[::ffff:([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\]/\1/' | cut -d: -f1 | sort | uniq -c | sort -nr | while read count ip; do
        # 如果 IP 是 *，跳过
        if [[ "$ip" == "*" ]]; then
            continue
        fi
        
        # 显示客户端 IP 和连接数
        echo "客户端 IP: $ip, 连接数: $count"
        
        # 获取 IP 的地理位置信息（使用 ip-api或者ipinfo.io）
        # ip-api
        # location=$(curl -s "http://ip-api.com/json/$ip?fields=country,regionName,city,isp")
        location=$(curl -s "http://ipinfo.io/$ip/json")
        
        # 提取国家、地区、城市和 ISP
        country=$(echo $location | jq -r .country)
        # ip-api
        # region=$(echo $location | jq -r .regionName)
        region=$(echo $location | jq -r .region)
        city=$(echo $location | jq -r .city)
        # ip-api
        # isp=$(echo $location | jq -r .isp)
        isp=$(echo $location | jq -r .org)
        
        # 显示地理位置信息
        echo "  地理位置: $country, $region, $city"
        echo "  ISP: $isp"
        echo
    done
}

# 查看Xray运行状态
view_status() {
    sudo systemctl status xray
}

# 主菜单
while true; do
    echo 
    echo "请选择操作："
    echo "1. 安装Xray"
    echo "2. 卸载Xray"
    echo "3. 修改端口"
    echo "4. 修改UUID"
    echo "5. 查看连接的配置信息"
    echo "6. 查看Xray实时日志"
    echo "7. 查看连接的客户端"
    echo "8. 查看Xray运行状态"
    echo "9. 启动Xray"
    echo "10. 停止Xray"
    echo "11. 重启Xray"
    echo "12. 退出脚本"
    read -p "请输入对应的序号: " choice
    echo 
    echo

    case $choice in
        1) install_xray ;;
        2) uninstall_xray ;;
        3) modify_port ;;
        4) modify_uuid ;;
        5) view_config_plus ;;
        6) view_realtime_logs ;;
        7) view_connections ;;
        8) view_status ;;
        9) systemctl start xray; echo "Xray 服务已启动。" ;;
        10) systemctl stop xray; echo "Xray 服务已停止。" ;;
        11) systemctl restart xray; echo "Xray 服务已重启。" ;;
        12) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
done
