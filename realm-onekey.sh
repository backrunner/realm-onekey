#!/bin/bash

# 定义 realm 版本变量
REALM_VERSION="v2.6.2"

# 检查realm是否已安装
if [ -f "/root/realm/realm" ]; then
    echo "检测到 realm 已安装。"
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
else
    echo "realm 未安装。"
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
fi

# 检查realm服务状态
check_realm_service_status() {
    if systemctl is-active --quiet realm; then
        echo -e "\033[0;32m启用\033[0m" # 绿色
    else
        echo -e "\033[0;31m未启用\033[0m" # 红色
    fi
}

# 显示菜单的函数
show_menu() {
    clear
    echo "欢迎使用 realm 一键转发脚本"
    echo "================="
    echo "1. 部署环境"
    echo "2. 添加转发"
    echo "3. 删除转发"
    echo "4. 启动服务"
    echo "5. 停止服务"
    echo "6. 一键卸载"
    echo "0. 退出脚本"
    echo "================="
    echo -e "realm 状态：${realm_status_color}${realm_status}\033[0m"
    echo -n "realm 转发状态："
    check_realm_service_status
}

# 生成基本配置文件的函数
generate_config() {
    cat > /root/realm/config.toml << EOF
[log]
level = "warn"
output = "stdout"

[network]
no_tcp = false
use_udp = true

# DNS 配置将在此处添加

# 转发规则将在此处添加
EOF
    echo "基础配置文件已生成：/root/realm/config.toml"
}

# 部署环境的函数
deploy_realm() {
    mkdir -p /root/realm
    cd /root/realm
    wget -O realm.tar.gz https://github.com/zhboner/realm/releases/download/${REALM_VERSION}/realm-x86_64-unknown-linux-gnu.tar.gz
    tar -xvf realm.tar.gz
    chmod +x realm

    # 生成基本配置文件
    generate_config

    # 询问用户是否使用自定义 DNS
    read -p "是否使用自定义 DNS 服务器? (y/N): " use_custom_dns
    if [[ $use_custom_dns == "Y" || $use_custom_dns == "y" ]]; then
        read -p "请输入 DNS 服务器地址 (多个地址用逗号分隔): " custom_dns
        sed -i '/# DNS 配置将在此处添加/c\[dns]\nnameservers = [\"'${custom_dns//,/\", \"}'\"]' /root/realm/config.toml
    else
        sed -i '/# DNS 配置将在此处添加/c\# 使用系统默认 DNS' /root/realm/config.toml
    fi

    # 创建服务文件
    echo "[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
WorkingDirectory=/root/realm
ExecStart=/root/realm/realm -c /root/realm/config.toml

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/realm.service
    systemctl daemon-reload
    # 更新realm状态变量
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
    echo "部署完成。"
}

# 卸载realm
uninstall_realm() {
    systemctl stop realm
    systemctl disable realm
    rm -f /etc/systemd/system/realm.service
    systemctl daemon-reload
    rm -rf /root/realm
    echo "realm 已被卸载。"
    # 更新realm状态变量
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
}

# 删除转发规则的函数
delete_forward() {
    echo "当前转发规则："
    local IFS=$'\n' # 设置IFS仅以换行符作为分隔符
    local lines=($(grep -n 'remote =' /root/realm/config.toml)) # 搜索所有包含转发规则的行
    if [ ${#lines[@]} -eq 0 ]; then
        echo "没有发现任何转发规则。"
        return
    fi
    local index=1
    for line in "${lines[@]}"; do
        echo "${index}. $(echo $line | cut -d '"' -f 2)" # 提取并显示端口信息
        let index+=1
    done

    echo "请输入要删除的转发规则序号，直接按回车返回主菜单。"
    read -p "选择: " choice
    if [ -z "$choice" ]; then
        echo "返回主菜单。"
        return
    fi

    if ! [[ $choice =~ ^[0-9]+$ ]]; then
        echo "无效输入，请输入数字。"
        return
    fi

    if [ $choice -lt 1 ] || [ $choice -gt ${#lines[@]} ]; then
        echo "选择超出范围，请输入有效序号。"
        return
    fi

    local chosen_line=${lines[$((choice-1))]} # 根据用户选择获取相应行
    local line_number=$(echo $chosen_line | cut -d ':' -f 1) # 获取行号

    # 计算要删除的范围，从listen开始到remote结束
    local start_line=$line_number
    local end_line=$(($line_number + 2))

    # 使用sed删除选中的转发规则
    sed -i "${start_line},${end_line}d" /root/realm/config.toml

    echo "转发规则已删除。"
}

# 添加转发规则
add_forward() {
    while true; do
        read -p "请输入目标IP: " ip
        read -p "请输入目标端口: " port
        read -p "是否绑定特定IP或网络接口? (y/N): " bind_option

        config="\n[[endpoints]]\nlisten = \"0.0.0.0:$port\"\nremote = \"$ip:$port\""

        if [[ $bind_option == "Y" || $bind_option == "y" ]]; then
            read -p "请选择绑定选项 (1: 特定IP, 2: 网络接口): " bind_type
            if [[ $bind_type == "1" ]]; then
                echo "可用的IP地址："
                ip_addresses=($(ip -o addr show | awk '{print $4}' | cut -d/ -f1 | sort -u))
                for i in "${!ip_addresses[@]}"; do
                    echo "$((i+1)). ${ip_addresses[i]}"
                done
                echo "$((${#ip_addresses[@]}+1)). 手动输入"

                read -p "请选择IP地址 (输入数字): " ip_choice
                if [[ $ip_choice -le ${#ip_addresses[@]} ]]; then
                    bind_ip=${ip_addresses[$((ip_choice-1))]}
                else
                    read -p "请输入要绑定的IP: " bind_ip
                fi
                config+="\nthrough = \"$bind_ip\""
            elif [[ $bind_type == "2" ]]; then
                echo "可用的网络接口："
                interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
                for i in "${!interfaces[@]}"; do
                    echo "$((i+1)). ${interfaces[i]}"
                done
                echo "$((${#interfaces[@]}+1)). 手动输入"

                read -p "请选择网络接口 (输入数字): " interface_choice
                if [[ $interface_choice -le ${#interfaces[@]} ]]; then
                    interface=${interfaces[$((interface_choice-1))]}
                else
                    read -p "请输入网络接口名称: " interface
                fi
                config+="\ninterface = \"$interface\""
            else
                echo "无效的选项，不进行绑定。"
            fi
        fi

        sed -i '/# 转发规则将在此处添加/i\'"$config" /root/realm/config.toml
        echo "转发规则已添加。"

        read -p "是否继续添加(y/N)? " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            break
        fi
    done
}

# 启动服务
start_service() {
    sudo systemctl unmask realm.service
    sudo systemctl daemon-reload
    sudo systemctl restart realm.service
    sudo systemctl enable realm.service
    echo "realm 服务已启动并设置为开机自启。"
}

# 停止服务
stop_service() {
    systemctl stop realm
    echo "realm 服务已停止。"
}

# 主循环
while true; do
    show_menu
    read -p "请选择一个选项: " choice
    case $choice in
        1)
            deploy_realm
            ;;
        2)
            add_forward
            ;;
        3)
            delete_forward
            ;;
        4)
            start_service
            ;;
        5)
            stop_service
            ;;
        6)
            uninstall_realm
            ;;
        0)
            exit 0
            ;;
        *)
            echo "无效选项: $choice"
            ;;
    esac
    read -p "按任意键继续..." key
done