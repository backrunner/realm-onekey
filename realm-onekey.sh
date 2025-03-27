#!/bin/bash
# -*- coding: utf-8 -*-

# 定义颜色
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_PURPLE="\033[0;35m"
COLOR_CYAN="\033[0;36m"
COLOR_RESET="\033[0m"

# 在颜色定义后添加发行版检测相关变量和函数
# 定义支持的发行版类型
DISTRO_TYPE=""
PKG_MANAGER=""
PKG_UPDATE=""
PKG_INSTALL=""

# 检测发行版类型
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            "debian"|"ubuntu"|"linuxmint"|"pop"|"elementary"|"zorin")
                DISTRO_TYPE="debian"
                PKG_MANAGER="apt-get"
                PKG_UPDATE="apt-get update"
                PKG_INSTALL="apt-get install -y"
                ;;
            "centos"|"rhel"|"fedora"|"rocky"|"almalinux"|"ol")
                DISTRO_TYPE="rhel"
                if command -v dnf >/dev/null 2>&1; then
                    PKG_MANAGER="dnf"
                    PKG_UPDATE="dnf check-update"
                    PKG_INSTALL="dnf install -y"
                else
                    PKG_MANAGER="yum"
                    PKG_UPDATE="yum check-update"
                    PKG_INSTALL="yum install -y"
                fi
                ;;
            "opensuse-leap"|"opensuse-tumbleweed"|"sles")
                DISTRO_TYPE="suse"
                PKG_MANAGER="zypper"
                PKG_UPDATE="zypper refresh"
                PKG_INSTALL="zypper install -y"
                ;;
            "arch"|"manjaro"|"endeavouros")
                DISTRO_TYPE="arch"
                PKG_MANAGER="pacman"
                PKG_UPDATE="pacman -Sy"
                PKG_INSTALL="pacman -S --noconfirm"
                ;;
            *)
                echo -e "${COLOR_RED}不支持的发行版：$ID${COLOR_RESET}"
                exit 1
                ;;
        esac
    else
        echo -e "${COLOR_RED}无法检测到系统发行版信息${COLOR_RESET}"
        exit 1
    fi
}

# 安装依赖包
install_dependencies() {
    echo -e "${COLOR_BLUE}正在安装必要的依赖...${COLOR_RESET}"

    # 检查 wget 是否已安装
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${COLOR_YELLOW}检测到系统未安装 wget，正在安装...${COLOR_RESET}"
        # 更新包管理器
        $PKG_UPDATE >/dev/null 2>&1

        case $DISTRO_TYPE in
            "debian")
                $PKG_INSTALL wget >/dev/null 2>&1
                ;;
            "rhel")
                $PKG_INSTALL wget >/dev/null 2>&1
                ;;
            "suse")
                $PKG_INSTALL wget >/dev/null 2>&1
                ;;
            "arch")
                $PKG_INSTALL wget >/dev/null 2>&1
                ;;
        esac

        if ! command -v wget >/dev/null 2>&1; then
            echo -e "${COLOR_RED}wget 安装失败，请手动安装后重试${COLOR_RESET}"
            exit 1
        fi
        echo -e "${COLOR_GREEN}wget 安装完成${COLOR_RESET}"
    fi

    # 定义基础依赖包（移除 wget，因为已经单独处理）
    local base_packages="curl tar"

    # 根据不同发行版安装特定依赖
    case $DISTRO_TYPE in
        "debian")
            $PKG_INSTALL $base_packages systemd >/dev/null 2>&1
            ;;
        "rhel")
            $PKG_INSTALL $base_packages systemd epel-release >/dev/null 2>&1
            ;;
        "suse")
            $PKG_INSTALL $base_packages systemd >/dev/null 2>&1
            ;;
        "arch")
            $PKG_INSTALL $base_packages systemd >/dev/null 2>&1
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo -e "${COLOR_GREEN}依赖安装完成${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}依赖安装失败${COLOR_RESET}"
        exit 1
    fi
}

echo -e "\033%G"  # 设置终端字符集

# 定义脚本版本
SCRIPT_VERSION="20250328"

# 定义 realm 版本变量
REALM_VERSION="v2.7.0"  # 预设版本
LATEST_VERSION=""       # 用于存储从 GitHub 获取的最新版本
GITHUB_TIMEOUT=5       # GitHub API 请求超时时间（秒）

# 定义基础目录（在脚本最前面添加）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REALM_DIR="${SCRIPT_DIR}/realm"

# 初始化状态变量
realm_status="未知"
realm_status_color="\033[0;31m" # 默认红色

# 首先定义 wait_key 函数（放在文件前面的函数定义部分）
wait_key() {
    read -r -p "按回车键继续..."
}

# 检查是否已经创建了快捷方式
check_and_create_shortcut() {
    local shortcut_name="realm-manager"
    local shortcut_path="/usr/local/bin/${shortcut_name}"
    local flag_file="${SCRIPT_DIR}/.no_shortcut"

    # 如果存在标记文件或已经创建了快捷方式，则不询问
    if [ -f "$flag_file" ] || [ -f "$shortcut_path" ]; then
        return
    fi

    echo -e "${COLOR_YELLOW}检测到未创建快捷方式。${COLOR_RESET}"
    read -r -p "是否创建 'realm-manager' 命令快捷方式？(y/N): " create_shortcut
    if [[ $create_shortcut == [Yy] ]]; then
        create_shortcut_internal
    else
        # 创建标记文件表示用户选择不创建快捷方式
        touch "$flag_file"
    fi
    echo
    sleep 1
}

# 添加创建快捷方式的内部函数
create_shortcut_internal() {
    local shortcut_name="realm-manager"
    local shortcut_path="/usr/local/bin/${shortcut_name}"
    local script_path=$(readlink -f "$0")

    if sudo ln -sf "$script_path" "$shortcut_path"; then
        sudo chmod +x "$shortcut_path"
        echo -e "${COLOR_GREEN}快捷方式已创建！现在可以使用 'realm-manager' 命令来启动管理脚本。${COLOR_RESET}"
        # 如果存在不创建快捷方式的标记文件，删除它
        rm -f "${SCRIPT_DIR}/.no_shortcut"
    else
        echo -e "${COLOR_RED}快捷方式创建失败！${COLOR_RESET}"
    fi
}

# 添加删除快捷方式的函数
remove_shortcut() {
    local shortcut_name="realm-manager"
    local shortcut_path="/usr/local/bin/${shortcut_name}"

    if [ -f "$shortcut_path" ]; then
        if sudo rm -f "$shortcut_path"; then
            echo -e "${COLOR_GREEN}快捷方式已删除${COLOR_RESET}"
            # 创建标记文件表示用户主动删除了快捷方式
            touch "${SCRIPT_DIR}/.no_shortcut"
        else
            echo -e "${COLOR_RED}删除快捷方式失败${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_YELLOW}快捷方式不存在${COLOR_RESET}"
    fi
    sleep 1
}

# 获取本地 realm 版本
get_local_realm_version() {
    if [ -f "${REALM_DIR}/realm" ]; then
        # 首先尝试从可执行文件名获取版本
        local executable_version=""
        if [ -L "${REALM_DIR}/realm" ]; then
            # 获取软链接指向的实际文件名
            local target_file=$(readlink "${REALM_DIR}/realm")
            # 尝试从文件名中提取版本号
            if [[ $target_file =~ realm-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
                executable_version="v${BASH_REMATCH[1]}"
            fi
        fi

        # 如果从文件名无法获取版本，或版本号大于定义的版本，则使用 --version 命令
        if [ -z "$executable_version" ] || [ "$(printf '%s\n' "$REALM_VERSION" "$executable_version" | sort -V | head -n1)" != "$REALM_VERSION" ]; then
            local cmd_version=$("${REALM_DIR}/realm" --version | awk '{print $2}')
            echo "v$cmd_version"
        else
            echo "$executable_version"
        fi
    else
        echo "未安装"
    fi
}

# 检查realm状态的函数
check_realm_status() {
    if [ -f "${REALM_DIR}/realm" ]; then
        realm_status="已安装"
        realm_status_color="\033[0;32m" # 绿色
    else
        realm_status="未安装"
        realm_status_color="\033[0;31m" # 红色
    fi
}

# 检查realm服务状态
check_realm_service_status() {
    if systemctl is-active --quiet realm; then
        echo -e "\033[0;32m启用\033[0m" # 绿色
    else
        echo -e "\033[0;31m未启用\033[0m" # 红色
    fi
}

# 修改获取最新版本的函数
get_latest_version() {
    # 如果已经获取过版本，直接返回
    if [ ! -z "$LATEST_VERSION" ]; then
        echo "$LATEST_VERSION"
        return
    fi
    return 1  # 如果没有预先获取版本，返回错误
}

# 修改初始化获取版本的函数
init_latest_version() {
    # 使用超时参数获取最新版本
    local latest=$(curl -s -m $GITHUB_TIMEOUT "https://api.github.com/repos/zhboner/realm/releases/latest" | grep -oP '"tag_name": "\K[^"]+')
    if [ $? -eq 0 ] && [ ! -z "$latest" ]; then
        LATEST_VERSION="$latest"
    else
        LATEST_VERSION="$REALM_VERSION"
        echo -e "${COLOR_YELLOW}获取最新版本失败${COLOR_RESET}"
        sleep 1
    fi
}

# 修改主菜单显示函数
show_main_menu() {
    clear
    echo "欢迎使用 realm 管理脚本 (v$SCRIPT_VERSION)"
    echo "================="
    echo "1. 服务管理"
    echo "2. 转发管理"
    echo "3. 系统维护"
    echo "0. 退出脚本"
    echo "================="
    echo -e "realm 状态：${realm_status_color}${realm_status}\033[0m"
    echo -e "realm 当前版本：$(get_local_realm_version)"
    echo -e "realm 最新版本：$(get_latest_version || echo "$REALM_VERSION")"
    echo -n "realm 转发状态："
    check_realm_service_status
}

# 修改菜单显示函数，移除内部的输入处理
show_service_menu() {
    clear
    echo "realm 服务管理"
    echo "================="
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo "4. 查看配置文件"
    echo "0. 返回主菜单"
    echo "================="
}

show_forward_menu() {
    clear
    echo "realm 转发管理"
    echo "================="
    echo "1. 添加转发"
    echo "2. 删除转发"
    echo "3. 修改转发"
    echo "4. 列出转发"
    echo "0. 返回主菜单"
    echo "================="
}

show_maintenance_menu() {
    clear
    echo "realm 系统维护"
    echo "================="
    echo "1. 部署 realm"
    echo "2. 升级 realm"
    echo "3. 卸载 realm"
    if [ -f "/usr/local/bin/realm-manager" ]; then
        echo "4. 删除快捷方式"
    else
        echo "4. 创建快捷方式"
    fi
    echo "0. 返回主菜单"
    echo "================="
}

# 查看配置文件内容
show_config() {
    if [ -f "${REALM_DIR}/config.toml" ]; then
        echo "当前配置文件内容："
        echo "==================="
        cat "${REALM_DIR}/config.toml"
        echo "==================="
    else
        echo "配置文件不存在！"
    fi
}

# 生成基本配置文件的函数
generate_config() {
    cat > "${REALM_DIR}/config.toml" << EOF
[log]
level = "warn"
output = "stdout"

[network]
no_tcp = false
use_udp = true

# DNS 配置将在此处添加

# 转发规则将在此处添加
EOF
    echo "基础配置文件已生成：${REALM_DIR}/config.toml"
}

# 验证 IP 地址格式的函数（新增）
validate_ip() {
    local ip=$1
    # IPv4 验证
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local IFS='.'
        read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if ! [[ $i =~ ^[0-9]+$ ]] || [ $i -lt 0 ] || [ $i -gt 255 ]; then
                return 1
            fi
        done
        return 0
    # IPv6 验证
    elif [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 获取系统所有 IP 地址（新增）
get_all_ips() {
    local -a ipv4_addrs=()
    local -a ipv6_addrs=()

    # 获取所有 IPv4 地址
    while IFS= read -r line; do
        if [[ $line =~ inet[[:space:]]([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            ipv4_addrs+=("${BASH_REMATCH[1]}")
        fi
    done < <(ip -4 addr show)

    # 获取所有 IPv6 地址
    while IFS= read -r line; do
        if [[ $line =~ inet6[[:space:]]([0-9a-fA-F:]+) ]]; then
            local addr="${BASH_REMATCH[1]}"
            # 排除链路本地地址
            if [[ ! $addr =~ ^fe80: ]]; then
                ipv6_addrs+=("$addr")
            fi
        fi
    done < <(ip -6 addr show)

    # 添加通配符地址
    ipv4_addrs+=("0.0.0.0")
    ipv6_addrs+=("[::]")

    # 打印所有地址
    echo "IPv4 地址:"
    for i in "${!ipv4_addrs[@]}"; do
        echo "$((i+1)). ${ipv4_addrs[i]}"
    done

    echo -e "\nIPv6 地址:"
    local ipv6_start=$((${#ipv4_addrs[@]}+1))
    for i in "${!ipv6_addrs[@]}"; do
        echo "$((ipv6_start+i)). ${ipv6_addrs[i]}"
    done

    # 返回所有地址
    echo "${ipv4_addrs[@]}" "${ipv6_addrs[@]}"
}

# 获取网卡及其主IP地址
get_interfaces_with_ips() {
    local interfaces=()
    local interface_ips=()
    
    # 获取所有网卡列表
    local all_interfaces=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    
    for interface in $all_interfaces; do
        # 尝试获取IPv4地址
        local ipv4=$(ip -4 addr show dev "$interface" 2>/dev/null | grep -w inet | head -n 1 | awk '{print $2}' | cut -d/ -f1)
        
        # 如果有IPv4地址，添加到列表
        if [[ -n "$ipv4" ]]; then
            interfaces+=("$interface")
            interface_ips+=("$ipv4")
            continue
        fi
        
        # 如果没有IPv4，尝试获取非链路本地IPv6地址
        local ipv6=$(ip -6 addr show dev "$interface" 2>/dev/null | grep -v "scope link" | grep -w inet6 | head -n 1 | awk '{print $2}' | cut -d/ -f1)
        
        # 如果有IPv6地址，添加到列表
        if [[ -n "$ipv6" ]]; then
            interfaces+=("$interface")
            interface_ips+=("$ipv6")
        fi
    done
    
    # 打印网卡和IP列表
    if [[ ${#interfaces[@]} -gt 0 ]]; then
        for i in "${!interfaces[@]}"; do
            echo "$((i+1)). ${interfaces[i]} (${interface_ips[i]})"
        done
    fi
    
    # 以特殊格式返回结果，方便后续处理
    echo "${interfaces[*]}" ";" "${interface_ips[*]}"
}

# 添加读取用户输入的函数（如果未定义）
read_input() {
    local prompt="$1"
    local input=""
    read -r -p "$prompt" input
    echo "$input"
}

# 修改部署函数中的版本使用
deploy_realm() {
    # 获取最新版本
    local deploy_version=$(get_latest_version || echo "$REALM_VERSION")

    # 检测并安装依赖
    install_dependencies

    # 创建目录并下载 realm
    mkdir -p "${REALM_DIR}"
    cd "${REALM_DIR}"

    echo -e "${COLOR_BLUE}下载 realm ${deploy_version}...${COLOR_RESET}"
    if ! wget -O realm.tar.gz "https://github.com/zhboner/realm/releases/download/${deploy_version}/realm-x86_64-unknown-linux-gnu.tar.gz"; then
        echo -e "${COLOR_RED}下载失败${COLOR_RESET}"
        return 1
    fi

    tar -xvf realm.tar.gz
    mv realm realm-${deploy_version#v}
    ln -sf realm-${deploy_version#v} realm
    chmod +x realm-${deploy_version#v}

    # 更新预设版本为最新版本
    REALM_VERSION="$deploy_version"

    # 生成基本配置文件
    generate_config

    # 询问用户是否使用自定义 DNS
    use_custom_dns=$(read_input "是否使用自定义 DNS 服务器? (y/N): ")
    if [[ $use_custom_dns == "Y" || $use_custom_dns == "y" ]]; then
        custom_dns=$(read_input "请输入 DNS 服务器地址 (多个地址用逗号分隔): ")
        sed -i '/# DNS 配置将在此处添加/c\[dns]\nnameservers = [\"'${custom_dns//,/\", \"}'\"]' "${REALM_DIR}/config.toml"
    else
        sed -i '/# DNS 配置将在此处添加/c\# 使用系统默认 DNS' "${REALM_DIR}/config.toml"
    fi

    # 创建 systemd 服务文件
    local service_path="/etc/systemd/system/realm.service"
    if [ "$DISTRO_TYPE" = "rhel" ]; then
        # RHEL 系统需要特殊处理 SELinux
        if command -v sestatus >/dev/null 2>&1 && sestatus | grep -q "enabled"; then
            echo -e "${COLOR_YELLOW}检测到 SELinux 已启用，正在配置相关权限...${COLOR_RESET}"
            $PKG_INSTALL policycoreutils-python-utils >/dev/null 2>&1
            semanage fcontext -a -t bin_t "${REALM_DIR}/realm(/.*)?"
            restorecon -R "${REALM_DIR}"
        fi
    fi

    # 创建服务文件
    cat > "$service_path" << EOF
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
WorkingDirectory=${REALM_DIR}
ExecStart=${REALM_DIR}/realm -c ${REALM_DIR}/config.toml
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # 更新 realm 状态变量
    realm_status="已安装"
    realm_status_color="\033[0;32m"
    echo -e "${COLOR_GREEN}部署完成${COLOR_RESET}"
}

# 卸载realm
uninstall_realm() {
    systemctl stop realm
    systemctl disable realm
    rm -f /etc/systemd/system/realm.service
    systemctl daemon-reload
    rm -rf "${REALM_DIR}"
    echo "realm 已被卸载。"
    # 更新realm状态变量
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
}

# 删除转发规则的函数
delete_forward() {
    echo "当前转发规则："
    local IFS=$'\n' # 设置IFS仅以换行符作为分隔符
    local lines=($(grep -n 'remote =' "${REALM_DIR}/config.toml")) # 搜索所有包含转发规则的行
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
    choice=$(read_input "选择: ")
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
    sed -i "${start_line},${end_line}d" "${REALM_DIR}/config.toml"

    echo "转发规则已删除"

    # 添加自动重启服务的逻辑
    echo -e "${COLOR_BLUE}正在重启 realm 服务以应用新配置...${COLOR_RESET}"
    if systemctl restart realm; then
        echo -e "${COLOR_GREEN}服务已重启，新配置已生效${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}服务重启失败，请手动检查服务状态${COLOR_RESET}"
        systemctl status realm
    fi
}

# 修改添加转发规则函数
add_forward() {
    while true; do
        # 获取目标 IP
        while true; do
            target_ip=$(read_input "请输入目标IP (IPv4/IPv6): ")
            if validate_ip "$target_ip"; then
                break
            else
                echo "无效的 IP 地址格式，请重新输入"
            fi
        done

        # 获取端口
        while true; do
            port=$(read_input "请输入目标端口: ")
            if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
                # 检查端口是否已被使用
                if grep -q "listen.*:$port\"" "${REALM_DIR}/config.toml"; then
                    echo "警告：端口 $port 已被使用，请检查现有配置："
                    grep -B1 -A1 "listen.*:$port\"" "${REALM_DIR}/config.toml"
                    read -r -p "是否继续使用此端口? (y/N): " continue_port
                    if [[ $continue_port != [Yy] ]]; then
                        continue
                    fi
                fi
                break
            else
                echo "无效的端口号，请输入 1-65535 之间的数字"
            fi
        done

        # 设置监听选项，让用户选择是使用IP还是网卡
        echo "请选择监听方式:"
        echo "1. 使用特定IP地址监听"
        echo "2. 使用特定网卡接口监听"
        listen_option=$(read_input "请选择 (1/2): ")

        config="\n[[endpoints]]"
        listen_interface=""

        if [[ $listen_option == "1" ]]; then
            # 使用IP地址监听
            listen_ip_option=$(read_input "是否指定监听IP? (默认: IPv4为0.0.0.0，IPv6为[::]) (y/N): ")

            # 根据目标IP类型设置默认监听IP
            if [[ "$target_ip" =~ : ]]; then
                listen_ip="[::]"  # IPv6 默认值
            else
                listen_ip="0.0.0.0"  # IPv4 默认值
            fi

            if [[ $listen_ip_option == "Y" || $listen_ip_option == "y" ]]; then
                echo "可用的IP地址："
                # 根据目标IP类型只显示相应的IP版本
                if [[ "$target_ip" =~ : ]]; then
                    # 只显示IPv6地址
                    echo "IPv6 地址:"
                    mapfile -t all_ips < <(ip -6 addr show | grep "inet6" | grep -v "fe80" | awk '{print $2}' | cut -d'/' -f1)
                    all_ips+=("[::]")
                else
                    # 只显示IPv4地址
                    echo "IPv4 地址:"
                    mapfile -t all_ips < <(ip -4 addr show | grep "inet" | awk '{print $2}' | cut -d'/' -f1)
                    all_ips+=("0.0.0.0")
                fi

                for i in "${!all_ips[@]}"; do
                    echo "$((i+1)). ${all_ips[i]}"
                done

                ip_choice=$(read_input "请选择监听IP (输入数字) 或直接输入IP: ")
                if [[ $ip_choice =~ ^[0-9]+$ ]] && [ $ip_choice -le ${#all_ips[@]} ]; then
                    listen_ip=${all_ips[$((ip_choice-1))]}
                else
                    # 验证手动输入的 IP 与目标 IP 版本是否匹配
                    if validate_ip "$ip_choice"; then
                        if [[ "$target_ip" =~ : ]] && [[ "$ip_choice" =~ : ]]; then
                            listen_ip=$ip_choice
                        elif [[ ! "$target_ip" =~ : ]] && [[ ! "$ip_choice" =~ : ]]; then
                            listen_ip=$ip_choice
                        else
                            echo "监听IP版本与目标IP版本不匹配，使用默认值"
                        fi
                    else
                        echo "无效的 IP 地址，使用默认值"
                    fi
                fi
            fi

            # IPv6 地址需要用方括号括起来
            if [[ "$listen_ip" =~ : ]] && [[ "$listen_ip" != \[*\] ]]; then
                listen_ip="[$listen_ip]"
            fi

            config+="\nlisten = \"$listen_ip:$port\""
        else
            # 使用网卡接口监听
            echo "可用的网卡接口："
            # 获取网卡和IP信息
            local interfaces_output=$(get_interfaces_with_ips)
            local interfaces_list=$(echo "$interfaces_output" | grep -E '^[0-9]+\.')
            local interfaces_data=$(echo "$interfaces_output" | grep -v -E '^[0-9]+\.')
            
            # 打印网卡列表
            if [[ -n "$interfaces_list" ]]; then
                echo "$interfaces_list"
            else
                echo "未找到可用网卡，使用默认IP监听"
                if [[ "$target_ip" =~ : ]]; then
                    listen_ip="[::]"  # IPv6 默认值
                else
                    listen_ip="0.0.0.0"  # IPv4 默认值
                fi
                config+="\nlisten = \"$listen_ip:$port\""
                continue
            fi
            
            # 解析网卡数据
            IFS=';' read -ra parts <<< "$interfaces_data"
            IFS=' ' read -ra interface_names <<< "${parts[0]}"
            
            if [[ ${#interface_names[@]} -eq 0 ]]; then
                echo "未找到可用网卡，使用默认IP监听"
                if [[ "$target_ip" =~ : ]]; then
                    listen_ip="[::]"  # IPv6 默认值
                else
                    listen_ip="0.0.0.0"  # IPv4 默认值
                fi
                config+="\nlisten = \"$listen_ip:$port\""
            else
                # 用户选择网卡
                interface_choice=$(read_input "请选择网卡接口 (输入数字): ")
                if [[ $interface_choice =~ ^[0-9]+$ ]] && [ $interface_choice -ge 1 ] && [ $interface_choice -le ${#interface_names[@]} ]; then
                    # 数组索引从0开始，但显示从1开始
                    listen_interface=${interface_names[$((interface_choice-1))]}
                    # 根据目标IP类型设置默认监听IP
                    if [[ "$target_ip" =~ : ]]; then
                        listen_ip="[::]"  # IPv6 默认值
                    else
                        listen_ip="0.0.0.0"  # IPv4 默认值
                    fi
                    config+="\nlisten = \"$listen_ip:$port\""
                    config+="\nlisten_interface = \"$listen_interface\""
                else
                    echo "无效的选择，使用默认IP地址监听"
                    if [[ "$target_ip" =~ : ]]; then
                        listen_ip="[::]"  # IPv6 默认值
                    else
                        listen_ip="0.0.0.0"  # IPv4 默认值
                    fi
                    config+="\nlisten = \"$listen_ip:$port\""
                fi
            fi
        fi

        # 添加remote配置
        if [[ "$target_ip" =~ : ]] && [[ "$target_ip" != \[*\] ]]; then
            target_ip="[$target_ip]"
        fi
        config+="\nremote = \"$target_ip:$port\""

        # 处理绑定选项
        read -p "是否绑定特定IP或网络接口用于出站连接? (y/N): " bind_option
        if [[ $bind_option == "Y" || $bind_option == "y" ]]; then
            read -p "请选择绑定选项 (1: 特定IP, 2: 网络接口): " bind_type
            if [[ $bind_type == "1" ]]; then
                echo "可用的IP地址："
                mapfile -t all_ips < <(get_all_ips)

                ip_choice=$(read_input "请选择IP地址 (输入数字) 或直接输入IP: ")
                if [[ $ip_choice =~ ^[0-9]+$ ]] && [ $ip_choice -le ${#all_ips[@]} ]; then
                    bind_ip=${all_ips[$((ip_choice-1))]}
                else
                    if validate_ip "$ip_choice"; then
                        bind_ip=$ip_choice
                    else
                        echo "无效的 IP 地址，跳过绑定"
                        bind_ip=""
                    fi
                fi

                if [ ! -z "$bind_ip" ]; then
                    if [[ $bind_ip =~ : ]]; then
                        bind_ip="[$bind_ip]"
                    fi
                    config+="\nthrough = \"$bind_ip\""
                fi
            elif [[ $bind_type == "2" ]]; then
                echo "可用的网络接口："
                # 获取网卡和IP信息
                local interfaces_output=$(get_interfaces_with_ips)
                local interfaces_list=$(echo "$interfaces_output" | grep -E '^[0-9]+\.')
                local interfaces_data=$(echo "$interfaces_output" | grep -v -E '^[0-9]+\.')
                
                # 打印网卡列表
                if [[ -n "$interfaces_list" ]]; then
                    echo "$interfaces_list"
                else
                    echo "未找到可用网卡，跳过绑定"
                    continue
                fi
                
                # 解析网卡数据
                IFS=';' read -ra parts <<< "$interfaces_data"
                IFS=' ' read -ra interface_names <<< "${parts[0]}"
                
                if [[ ${#interface_names[@]} -eq 0 ]]; then
                    echo "未找到可用网卡，跳过绑定"
                    continue
                fi
                
                # 用户选择网卡
                interface_choice=$(read_input "请选择网络接口 (输入数字): ")
                if [[ $interface_choice =~ ^[0-9]+$ ]] && [ $interface_choice -ge 1 ] && [ $interface_choice -le ${#interface_names[@]} ]; then
                    interface=${interface_names[$((interface_choice-1))]}
                    config+="\ninterface = \"$interface\""
                else
                    echo "无效的选项，不进行绑定"
                fi
            fi
        fi

        sed -i '/# 转发规则将在此处添加/i\'"$config" "${REALM_DIR}/config.toml"
        echo "转发规则已添加："

        if [ -z "$listen_interface" ]; then
            if [[ $listen_option == "1" ]]; then
                echo "监听地址: $listen_ip:$port"
            else
                echo "监听地址: 0.0.0.0:$port (未选择特定网卡)"
            fi
        else
            echo "监听地址: 0.0.0.0:$port (网卡: $listen_interface)"
        fi

        echo "转发地址: $target_ip:$port"

        # 添加自动重启服务的逻辑
        echo -e "${COLOR_BLUE}正在重启 realm 服务以应用新配置...${COLOR_RESET}"
        if systemctl restart realm; then
            echo -e "${COLOR_GREEN}服务已重启，新配置已生效${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}服务重启失败，请手动检查服务状态${COLOR_RESET}"
            systemctl status realm
        fi

        read -p "是否继续添加(y/N)? " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            break
        fi
    done
}

# 添加修改转发的函数
modify_forward() {
    echo "当前转发规则："
    list_forwards

    echo "请输入要修改的转发规则序号，直接按回车返回主菜单。"
    read -r -p "选择: " choice
    if [ -z "$choice" ]; then
        return
    fi

    # 提取规则信息
    local rule_sections=($(grep -n '\[\[endpoints\]\]' "${REALM_DIR}/config.toml" | cut -d: -f1))

    if ! [[ $choice =~ ^[0-9]+$ ]] || [ $choice -lt 1 ] || [ $choice -gt ${#rule_sections[@]} ]; then
        echo "无效的选择。"
        return
    fi

    # 确定所选规则的开始行
    local start_line=${rule_sections[$((choice-1))]}
    local end_line

    # 确定该规则的结束行
    if [ $choice -lt ${#rule_sections[@]} ]; then
        end_line=$((${rule_sections[$choice]}-1))
    else
        # 如果是最后一个规则，使用文件末尾
        end_line=$(wc -l < "${REALM_DIR}/config.toml")
    fi

    # 提取该规则的所有配置
    local rule_content=$(sed -n "${start_line},${end_line}p" "${REALM_DIR}/config.toml")

    # 解析现有配置
    local current_listen=$(echo "$rule_content" | grep 'listen =' | grep -oP 'listen = "\K[^"]+')
    local current_remote=$(echo "$rule_content" | grep 'remote =' | grep -oP 'remote = "\K[^"]+')
    local current_listen_interface=$(echo "$rule_content" | grep 'listen_interface =' | grep -oP 'listen_interface = "\K[^"]+')

    # 解析监听地址
    local current_listen_ip=""
    local current_listen_port=""

    if [ -n "$current_listen" ]; then
        current_listen_ip=${current_listen%:*}
        current_listen_port=${current_listen#*:}
        # 移除 IPv6 地址的方括号
        current_listen_ip=${current_listen_ip#[}
        current_listen_ip=${current_listen_ip%]}
    fi

    echo "当前配置："
    if [ -n "$current_listen_interface" ]; then
        echo "监听网卡: $current_listen_interface"
    fi
    echo "监听地址: $current_listen"
    echo "转发地址: $current_remote"

    # 询问修改项
    echo "请选择要修改的内容:"
    echo "1. 修改监听方式 (IP或网卡)"
    echo "2. 修改监听端口"
    echo "3. 修改目标地址"
    echo "0. 取消修改"

    read -r -p "请选择: " modify_choice

    case $modify_choice in
        1)
            # 修改监听方式
            echo "请选择新的监听方式:"
            echo "1. 使用特定IP地址监听"
            echo "2. 使用特定网卡接口监听"
            read -r -p "请选择 (1/2): " new_listen_mode

            # 备份配置
            cp "${REALM_DIR}/config.toml" "${REALM_DIR}/config.toml.bak"

            if [[ $new_listen_mode == "1" ]]; then
                # 使用IP地址监听，移除网卡监听配置
                sed -i "/listen_interface/d" "${REALM_DIR}/config.toml"

                # 选择新的IP地址
                echo "可用的IP地址："
                if [[ "${current_remote}" =~ .*:.* && ! "${current_remote}" =~ [0-9]+\.[0-9]+ ]]; then
                    # IPv6 目标地址
                    echo "IPv6 地址:"
                    mapfile -t all_ips < <(ip -6 addr show | grep "inet6" | grep -v "fe80" | awk '{print $2}' | cut -d'/' -f1)
                    all_ips+=("[::]")
                else
                    # IPv4 目标地址
                    echo "IPv4 地址:"
                    mapfile -t all_ips < <(ip -4 addr show | grep "inet" | awk '{print $2}' | cut -d'/' -f1)
                    all_ips+=("0.0.0.0")
                fi

                for i in "${!all_ips[@]}"; do
                    echo "$((i+1)). ${all_ips[i]}"
                done

                ip_choice=$(read_input "请选择监听IP (输入数字) 或直接输入IP: ")
                if [[ $ip_choice =~ ^[0-9]+$ ]] && [ $ip_choice -le ${#all_ips[@]} ]; then
                    new_listen_ip=${all_ips[$((ip_choice-1))]}
                else
                    if validate_ip "$ip_choice"; then
                        new_listen_ip=$ip_choice
                    else
                        echo "无效的 IP 地址，使用默认值"
                        if [[ "${current_remote}" =~ .*:.* && ! "${current_remote}" =~ [0-9]+\.[0-9]+ ]]; then
                            new_listen_ip="[::]"
                        else
                            new_listen_ip="0.0.0.0"
                        fi
                    fi
                fi

                # IPv6 地址需要用方括号括起来
                if [[ "$new_listen_ip" =~ : ]] && [[ "$new_listen_ip" != \[*\] ]]; then
                    new_listen_ip="[$new_listen_ip]"
                fi

                # 更新配置文件中的监听地址
                sed -i "/listen =/ c\\listen = \"$new_listen_ip:$current_listen_port\"" "${REALM_DIR}/config.toml"
            else
                # 使用网卡接口监听
                echo "可用的网卡接口："
                # 获取网卡和IP信息
                local interfaces_output=$(get_interfaces_with_ips)
                local interfaces_list=$(echo "$interfaces_output" | grep -E '^[0-9]+\.')
                local interfaces_data=$(echo "$interfaces_output" | grep -v -E '^[0-9]+\.')
                
                # 打印网卡列表
                if [[ -n "$interfaces_list" ]]; then
                    echo "$interfaces_list"
                else
                    echo "未找到可用网卡，取消修改"
                    return
                fi
                
                # 解析网卡数据
                IFS=';' read -ra parts <<< "$interfaces_data"
                IFS=' ' read -ra interface_names <<< "${parts[0]}"
                
                if [[ ${#interface_names[@]} -eq 0 ]]; then
                    echo "未找到可用网卡，取消修改"
                    return
                fi
                
                # 用户选择网卡
                interface_choice=$(read_input "请选择网卡接口 (输入数字): ")
                if [[ $interface_choice =~ ^[0-9]+$ ]] && [ $interface_choice -ge 1 ] && [ $interface_choice -le ${#interface_names[@]} ]; then
                    new_listen_interface=${interface_names[$((interface_choice-1))]}
                    
                    # 查找是否已有listen_interface行
                    if grep -q "listen_interface" <(echo "$rule_content"); then
                        # 更新现有行
                        sed -i "/listen_interface =/ c\\listen_interface = \"$new_listen_interface\"" "${REALM_DIR}/config.toml"
                    else
                        # 在listen行后添加新行
                        sed -i "/listen =/ a\\listen_interface = \"$new_listen_interface\"" "${REALM_DIR}/config.toml"
                    fi
                    
                    # 确保listen地址为正确的通配符地址
                    if [[ "${current_remote}" =~ .*:.* && ! "${current_remote}" =~ [0-9]+\.[0-9]+ ]]; then
                        # IPv6 目标，使用[::]
                        sed -i "/listen =/ c\\listen = \"[::]:$current_listen_port\"" "${REALM_DIR}/config.toml"
                    else
                        # IPv4 目标，使用0.0.0.0
                        sed -i "/listen =/ c\\listen = \"0.0.0.0:$current_listen_port\"" "${REALM_DIR}/config.toml"
                    fi
                else
                    echo "无效的选择，保持原配置"
                fi
            fi
            ;;
        2)
            # 修改监听端口
            while true; do
                read -r -p "请输入新的端口号: " new_port
                if [[ $new_port =~ ^[0-9]+$ ]] && [ $new_port -ge 1 ] && [ $new_port -le 65535 ]; then
                    # 更新配置文件中的端口
                    if [[ -n "$current_listen" ]]; then
                        new_listen="${current_listen%:*}:$new_port"
                        sed -i "/listen =/ c\\listen = \"$new_listen\"" "${REALM_DIR}/config.toml"
                    fi
                    break
                else
                    echo "无效的端口号，请输入 1-65535 之间的数字"
                fi
            done
            ;;
        3)
            # 修改目标地址
            while true; do
                target_ip=$(read_input "请输入新的目标IP (IPv4/IPv6): ")
                if validate_ip "$target_ip"; then
                    break
                else
                    echo "无效的 IP 地址格式，请重新输入"
                fi
            done

            # 获取端口
            while true; do
                port=$(read_input "请输入新的目标端口: ")
                if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
                    break
                else
                    echo "无效的端口号，请输入 1-65535 之间的数字"
                fi
            done

            # IPv6 地址需要用方括号括起来
            if [[ "$target_ip" =~ : ]] && [[ "$target_ip" != \[*\] ]]; then
                target_ip="[$target_ip]"
            fi

            # 更新配置文件中的目标地址
            sed -i "/remote =/ c\\remote = \"$target_ip:$port\"" "${REALM_DIR}/config.toml"
            ;;
        0)
            echo "取消修改。"
            return
            ;;
        *)
            echo "无效选项，取消修改。"
            return
            ;;
    esac

    echo "转发规则已更新"

    # 自动重启服务
    echo -e "${COLOR_BLUE}正在重启 realm 服务以应用新配置...${COLOR_RESET}"
    if systemctl restart realm; then
        echo -e "${COLOR_GREEN}服务已重启，新配置已生效${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}服务重启失败，请手动检查服务状态${COLOR_RESET}"
        systemctl status realm
    fi
}

# 启动服务
start_service() {
    # 检查服务文件是否存在
    if [ ! -f "/etc/systemd/system/realm.service" ]; then
        echo -e "${COLOR_RED}错误: realm 服务文件不存在${COLOR_RESET}"
        wait_key
        return 1
    fi

    # 检查可执行文件是否存在
    if [ ! -f "${REALM_DIR}/realm" ]; then
        echo -e "${COLOR_RED}错误: realm 可执行文件不存在${COLOR_RESET}"
        wait_key
        return 1
    fi

    # 检查配置文件是否存在
    if [ ! -f "${REALM_DIR}/config.toml" ]; then
        echo -e "${COLOR_RED}错误: realm 配置文件不存在${COLOR_RESET}"
        wait_key
        return 1
    fi

    # 重新加载 systemd 配置
    echo -e "${COLOR_BLUE}重新加载 systemd 配置...${COLOR_RESET}"
    sudo systemctl daemon-reload

    # 取消服务屏蔽（如果被屏蔽）
    echo -e "${COLOR_BLUE}取消服务屏蔽...${COLOR_RESET}"
    sudo systemctl unmask realm.service

    # 启动服务
    echo -e "${COLOR_BLUE}正在启动 realm 服务...${COLOR_RESET}"
    if ! sudo systemctl start realm.service; then
        echo -e "${COLOR_RED}错误: 启动服务失败${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}查看服务状态...${COLOR_RESET}"
        sudo systemctl status realm.service
        wait_key
        return 1
    fi

    # 设置开机自启
    echo -e "${COLOR_BLUE}设置开机自启...${COLOR_RESET}"
    if ! sudo systemctl enable realm.service; then
        echo -e "${COLOR_YELLOW}警告: 设置开机自启失败${COLOR_RESET}"
    fi

    # 验证服务状态
    if systemctl is-active --quiet realm; then
        echo -e "${COLOR_GREEN}realm 服务已成功启动并设置为开机自启${COLOR_RESET}"
        wait_key
        return 0
    else
        echo -e "${COLOR_RED}错误: 服务启动失败，请检查日志${COLOR_RESET}"
        sudo systemctl status realm.service
        wait_key
        return 1
    fi
}

# 停止服务
stop_service() {
    echo -e "${COLOR_BLUE}正在停止 realm 服务...${COLOR_RESET}"
    if systemctl stop realm; then
        echo -e "${COLOR_GREEN}realm 服务已停止${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}停止服务失败${COLOR_RESET}"
    fi
    wait_key
    return 0
}

# 重启服务
restart_service() {
    echo -e "${COLOR_BLUE}正在重启 realm 服务...${COLOR_RESET}"
    if systemctl restart realm; then
        echo -e "${COLOR_GREEN}realm 服务已重启${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}重启服务失败${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}查看服务状态...${COLOR_RESET}"
        systemctl status realm
    fi
    wait_key
    return 0
}

# 修改升级函数
upgrade_realm() {
    local current_version=$(get_local_realm_version)
    if [ "$current_version" == "未安装" ]; then
        echo "realm 未安装，请先安装。"
        return
    fi

    # 获取最新版本
    local latest_version=$(get_latest_version || echo "$REALM_VERSION")

    echo "当前版本: $current_version"
    echo "最新版本: $latest_version"

    if [ "$current_version" == "$latest_version" ]; then
        echo "已经是最新版本，无需升级。"
        return
    fi

    confirm=$(read_input "是否升级到 $latest_version? (y/N): ")
    if [[ $confirm != [Yy] ]]; then
        echo "取消升级。"
        return
    fi

    cd "${REALM_DIR}"
    # 停止服务
    systemctl stop realm

    # 备份当前配置文件
    cp config.toml config.toml.backup

    # 删除旧版本文件
    rm -f realm.tar.gz
    rm -f realm  # 删除软链接
    rm -f realm-*  # 删除所有旧版本

    # 下载并安装新版本
    wget -O realm.tar.gz "https://github.com/zhboner/realm/releases/download/${latest_version}/realm-x86_64-unknown-linux-gnu.tar.gz"
    if [ $? -ne 0 ]; then
        echo -e "${COLOR_RED}下载失败，升级中止${COLOR_RESET}"
        # 恢复配置文件
        mv config.toml.backup config.toml
        return 1
    fi

    tar -xvf realm.tar.gz
    mv realm realm-${latest_version#v}
    ln -sf realm-${latest_version#v} realm
    chmod +x realm-${latest_version#v}

    # 恢复配置文件
    mv config.toml.backup config.toml

    # 更新预设版本为最新版本
    REALM_VERSION="$latest_version"

    echo -e "${COLOR_GREEN}realm 已升级到 $latest_version${COLOR_RESET}"
    systemctl restart realm
    echo -e "${COLOR_GREEN}realm 服务已重启${COLOR_RESET}"
}

# 列出所有转发规则
list_forwards() {
    if [ ! -f "${REALM_DIR}/config.toml" ]; then
        echo "配置文件不存在！"
        return
    fi

    echo "当前所有转发规则："
    echo "==================="

    # 检查是否有转发规则
    local has_rules=$(grep -c "\[\[endpoints\]\]" "${REALM_DIR}/config.toml")
    
    if [ "$has_rules" -eq 0 ]; then
        echo "没有找到任何转发规则。"
        echo "==================="
        return
    fi

    local rule_count=0
    
    # 使用简单方法逐段读取规则块
    while IFS= read -r line; do
        if [[ "$line" == *"[[endpoints]]"* ]]; then
            ((rule_count++))
            echo -e "\n规则 $rule_count:"
            
            # 获取这个规则后面的几行
            local section_content=$(sed -n "/\[\[endpoints\]\]/,/\[\[endpoints\]\]/p" "${REALM_DIR}/config.toml" | 
                                  sed -n "$((rule_count))q;$((rule_count))p,/\[\[endpoints\]\]/p" | 
                                  sed '$d')
            
            # 提取并打印信息
            local listen=$(echo "$section_content" | grep 'listen =' | grep -o '"[^"]*"' | tr -d '"')
            local remote=$(echo "$section_content" | grep 'remote =' | grep -o '"[^"]*"' | tr -d '"')
            local listen_interface=$(echo "$section_content" | grep 'listen_interface =' | grep -o '"[^"]*"' | tr -d '"')
            local through=$(echo "$section_content" | grep 'through =' | grep -o '"[^"]*"' | tr -d '"')
            local interface=$(echo "$section_content" | grep 'interface =' | grep -o '"[^"]*"' | tr -d '"')
            
            echo "监听地址: $listen"
            [ ! -z "$listen_interface" ] && echo "监听网卡: $listen_interface"
            echo "转发地址: $remote"
            [ ! -z "$through" ] && echo "绑定IP: $through"
            [ ! -z "$interface" ] && echo "绑定网卡: $interface"
        fi
    done < <(grep -n "\[\[endpoints\]\]" "${REALM_DIR}/config.toml")
    
    echo -e "\n==================="
}

# 在主循环之前添加
# 检查是否在终端中运行
if [ ! -t 0 ]; then
    # 如果不是在终端中运行，则自动进入交互模式
    exec </dev/tty >/dev/tty 2>&1
fi

# 在脚本开始处（主循环之前）添加发行版检测
detect_distro
init_latest_version  # 初始化时获取最新版本

# 主循环
while true; do
    check_realm_status
    show_main_menu
    read -r -p "请选择一个选项: " choice
    case $choice in
        1)  # 服务管理
            while true; do
                show_service_menu
                read -r -p "请选择一个选项: " service_choice
                case $service_choice in
                    1)
                        start_service
                        break
                        ;;
                    2)
                        stop_service
                        break
                        ;;
                    3)
                        restart_service
                        break
                        ;;
                    4)
                        show_config
                        wait_key
                        ;;
                    0) break ;;
                    *)
                        echo "无效选项: $service_choice"
                        wait_key
                        ;;
                esac
            done
            ;;
        2)  # 转发管理
            while true; do
                show_forward_menu
                read -r -p "请选择一个选项: " forward_choice
                case $forward_choice in
                    1) add_forward ;;
                    2) delete_forward ;;
                    3) modify_forward ;;
                    4) list_forwards ;;
                    0) break ;;
                    *) echo "无效选项: $forward_choice" ;;
                esac
                wait_key
            done
            ;;
        3)  # 系统维护
            while true; do
                show_maintenance_menu
                read -r -p "请选择一个选项: " maintenance_choice
                case $maintenance_choice in
                    1) deploy_realm ;;
                    2) upgrade_realm ;;
                    3) uninstall_realm ;;
                    4)
                        if [ -f "/usr/local/bin/realm-manager" ]; then
                            remove_shortcut
                        else
                            create_shortcut_internal
                        fi
                        ;;
                    0) break ;;
                    *) echo "无效选项: $maintenance_choice" ;;
                esac
                wait_key
            done
            ;;
        0)
            exit 0
            ;;
        *)
            echo "无效选项: $choice"
            wait_key
            ;;
    esac
done

# 在主循环之前调用这个函数
# 在脚本开始处（主循环之前）添加：
check_and_create_shortcut