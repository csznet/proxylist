#!/bin/bash

# ProxyList Domain Add Script
# GitHub: github.com/csznet/proxylist

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置文件路径
SNIPROXY_CONF="/etc/sniproxy.conf"
DNSMASQ_CONF="/etc/dnsmasq.d/custom_netflix.conf"

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_highlight() {
    echo -e "${CYAN}$1${NC}"
}

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 权限运行此脚本"
        echo "使用命令: sudo $0"
        exit 1
    fi
}

# 检查服务是否存在
check_service() {
    local service_name=$1
    local service_exists=0

    # 检查 systemctl
    if command -v systemctl &> /dev/null; then
        if systemctl list-unit-files | grep -q "^${service_name}.service"; then
            service_exists=1
        fi
    fi

    # 检查 service 命令
    if [ $service_exists -eq 0 ] && command -v service &> /dev/null; then
        if service --status-all 2>&1 | grep -q "$service_name"; then
            service_exists=1
        fi
    fi

    # 检查进程
    if [ $service_exists -eq 0 ]; then
        if pgrep -x "$service_name" > /dev/null; then
            service_exists=1
        fi
    fi

    return $service_exists
}

# 检查并显示服务状态
check_services() {
    echo ""
    print_highlight "========================================="
    print_highlight "  检查服务状态"
    print_highlight "========================================="
    echo ""

    local has_sniproxy=0
    local has_dnsmasq=0

    # 检查 SNIProxy
    print_info "检查 SNIProxy 服务..."
    if check_service "sniproxy"; then
        print_success "SNIProxy 服务已安装"
        has_sniproxy=1
    else
        print_warning "未检测到 SNIProxy 服务"
    fi

    # 检查 DNSMasq
    print_info "检查 DNSMasq 服务..."
    if check_service "dnsmasq"; then
        print_success "DNSMasq 服务已安装"
        has_dnsmasq=1
    else
        print_warning "未检测到 DNSMasq 服务"
    fi

    echo ""

    if [ $has_sniproxy -eq 0 ] && [ $has_dnsmasq -eq 0 ]; then
        print_error "未检测到任何代理服务，脚本退出"
        exit 1
    fi

    return 0
}

# 扫描并检查配置文件
scan_config_files() {
    echo ""
    print_highlight "========================================="
    print_highlight "  扫描配置文件"
    print_highlight "========================================="
    echo ""

    local sniproxy_found=0
    local dnsmasq_found=0

    # 检查 SNIProxy 配置
    print_info "查找 SNIProxy 配置文件..."
    if [ -f "$SNIPROXY_CONF" ]; then
        print_success "找到配置文件: $SNIPROXY_CONF"
        sniproxy_found=1
    else
        # 尝试其他可能的位置
        local alt_paths=("/etc/sniproxy/sniproxy.conf" "/usr/local/etc/sniproxy.conf")
        for path in "${alt_paths[@]}"; do
            if [ -f "$path" ]; then
                SNIPROXY_CONF="$path"
                print_success "找到配置文件: $SNIPROXY_CONF"
                sniproxy_found=1
                break
            fi
        done

        if [ $sniproxy_found -eq 0 ]; then
            print_warning "未找到 SNIProxy 配置文件"
        fi
    fi

    # 检查 DNSMasq 配置
    print_info "查找 DNSMasq 配置文件..."
    if [ -f "$DNSMASQ_CONF" ]; then
        print_success "找到配置文件: $DNSMASQ_CONF"
        dnsmasq_found=1
    else
        # 尝试其他可能的位置
        local alt_paths=("/etc/dnsmasq.conf" "/etc/dnsmasq.d/custom.conf" "/usr/local/etc/dnsmasq.conf")
        for path in "${alt_paths[@]}"; do
            if [ -f "$path" ]; then
                print_warning "找到配置文件: $path"
                read -p "是否使用此文件作为 DNSMasq 配置? [y/N]: " use_alt </dev/tty
                if [[ $use_alt =~ ^[Yy]$ ]]; then
                    DNSMASQ_CONF="$path"
                    print_success "使用配置文件: $DNSMASQ_CONF"
                    dnsmasq_found=1
                    break
                fi
            fi
        done

        if [ $dnsmasq_found -eq 0 ]; then
            print_warning "未找到 DNSMasq 配置文件"
        fi
    fi

    echo ""

    if [ $sniproxy_found -eq 0 ] && [ $dnsmasq_found -eq 0 ]; then
        print_error "未找到任何配置文件，脚本退出"
        exit 1
    fi

    # 保存找到的配置状态
    echo "$sniproxy_found" > /tmp/sniproxy_found
    echo "$dnsmasq_found" > /tmp/dnsmasq_found
}

# 检查域名是否已存在
check_domain_exists() {
    local domain=$1
    local config_file=$2
    local config_type=$3

    if [ "$config_type" == "sniproxy" ]; then
        # SNIProxy 格式: .*domain\.com$ *
        if grep -q ".*${domain//./\\.}\\\$" "$config_file"; then
            return 0  # 存在
        fi
    elif [ "$config_type" == "dnsmasq" ]; then
        # DNSMasq 格式: address=/domain.com/IP
        if grep -q "address=/${domain}/" "$config_file"; then
            return 0  # 存在
        fi
    fi

    return 1  # 不存在
}

# 添加域名到 SNIProxy
add_to_sniproxy() {
    local domain=$1

    # 检查是否重复
    if check_domain_exists "$domain" "$SNIPROXY_CONF" "sniproxy"; then
        print_warning "域名 $domain 已存在于 SNIProxy 配置中，跳过"
        return 1
    fi

    # 转义点号
    local escaped_domain="${domain//./\\.}"

    # 在 table 块的结尾（最后一个 } 之前）插入新域名
    # 找到最后一个 } 的行号
    local last_brace_line=$(grep -n "^}" "$SNIPROXY_CONF" | tail -1 | cut -d: -f1)

    if [ -z "$last_brace_line" ]; then
        print_error "无法找到 SNIProxy 配置文件中的 table 块结束位置"
        return 1
    fi

    # 在最后一个 } 之前插入新行
    sed -i "${last_brace_line}i\\    .*${escaped_domain}\$ *" "$SNIPROXY_CONF"

    print_success "已添加 $domain 到 SNIProxy 配置"
    return 0
}

# 添加域名到 DNSMasq
add_to_dnsmasq() {
    local domain=$1

    # 检查是否重复
    if check_domain_exists "$domain" "$DNSMASQ_CONF" "dnsmasq"; then
        print_warning "域名 $domain 已存在于 DNSMasq 配置中，跳过"
        return 1
    fi

    # 获取配置文件中使用的IP地址
    local ip_address=$(grep -oP 'address=/[^/]+/\K[0-9.]+' "$DNSMASQ_CONF" | head -1)

    if [ -z "$ip_address" ]; then
        print_warning "无法从配置文件中提取IP地址，使用默认 1.1.1.1"
        ip_address="1.1.1.1"
    fi

    # 添加到文件末尾
    echo "address=/${domain}/${ip_address}" >> "$DNSMASQ_CONF"

    print_success "已添加 $domain 到 DNSMasq 配置 (IP: $ip_address)"
    return 0
}

# 重启服务
restart_services() {
    local restart_sniproxy=$1
    local restart_dnsmasq=$2

    echo ""
    print_highlight "========================================="
    print_highlight "  重启服务"
    print_highlight "========================================="
    echo ""

    # 重启 SNIProxy
    if [ $restart_sniproxy -eq 1 ]; then
        print_info "重启 SNIProxy 服务..."
        if systemctl is-active --quiet sniproxy 2>/dev/null; then
            systemctl restart sniproxy && print_success "SNIProxy 服务已重启"
        elif service sniproxy status >/dev/null 2>&1; then
            service sniproxy restart && print_success "SNIProxy 服务已重启"
        else
            print_warning "请手动重启 SNIProxy 服务"
        fi
    fi

    # 重启 DNSMasq
    if [ $restart_dnsmasq -eq 1 ]; then
        print_info "重启 DNSMasq 服务..."
        if systemctl is-active --quiet dnsmasq 2>/dev/null; then
            systemctl restart dnsmasq && print_success "DNSMasq 服务已重启"
        elif service dnsmasq status >/dev/null 2>&1; then
            service dnsmasq restart && print_success "DNSMasq 服务已重启"
        else
            print_warning "请手动重启 DNSMasq 服务"
        fi
    fi
}

# 验证域名格式
validate_domain() {
    local domain=$1

    # 基本的域名格式验证
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi

    return 0
}

# 主函数
main() {
    # 检查权限
    check_root

    # 显示标题
    clear
    echo ""
    print_highlight "========================================="
    print_highlight "  ProxyList 域名添加工具"
    print_highlight "  GitHub: github.com/csznet/proxylist"
    print_highlight "========================================="

    # 检查服务
    check_services

    # 扫描配置文件
    scan_config_files

    # 读取配置状态
    local sniproxy_found=$(cat /tmp/sniproxy_found)
    local dnsmasq_found=$(cat /tmp/dnsmasq_found)

    # 提示用户输入域名
    echo ""
    print_highlight "========================================="
    print_highlight "  添加域名"
    print_highlight "========================================="
    echo ""
    print_info "请输入要添加的域名（支持多个域名，用空格或逗号分隔）"
    print_info "示例: example.com google.com, openai.com"
    echo ""
    read -p "域名: " domains_input </dev/tty

    # 清理输入，支持空格和逗号分隔
    domains_input=$(echo "$domains_input" | tr ',' ' ')

    # 转换为数组
    read -ra domains <<< "$domains_input"

    if [ ${#domains[@]} -eq 0 ]; then
        print_error "未输入任何域名，脚本退出"
        exit 1
    fi

    echo ""
    print_info "准备添加 ${#domains[@]} 个域名..."
    echo ""

    local added_sniproxy=0
    local added_dnsmasq=0

    # 处理每个域名
    for domain in "${domains[@]}"; do
        # 去除空格
        domain=$(echo "$domain" | xargs)

        if [ -z "$domain" ]; then
            continue
        fi

        print_highlight "处理域名: $domain"

        # 验证域名格式
        if ! validate_domain "$domain"; then
            print_error "域名格式无效: $domain，跳过"
            echo ""
            continue
        fi

        # 添加到 SNIProxy
        if [ $sniproxy_found -eq 1 ]; then
            if add_to_sniproxy "$domain"; then
                added_sniproxy=1
            fi
        fi

        # 添加到 DNSMasq
        if [ $dnsmasq_found -eq 1 ]; then
            if add_to_dnsmasq "$domain"; then
                added_dnsmasq=1
            fi
        fi

        echo ""
    done

    # 重启服务
    if [ $added_sniproxy -eq 1 ] || [ $added_dnsmasq -eq 1 ]; then
        restart_services $added_sniproxy $added_dnsmasq
        echo ""
        print_success "所有域名已处理完成！"
    else
        echo ""
        print_warning "没有添加任何新域名"
    fi

    # 清理临时文件
    rm -f /tmp/sniproxy_found /tmp/dnsmasq_found
}

# 运行主函数
main
