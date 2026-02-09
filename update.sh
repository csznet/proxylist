#!/bin/bash

# ProxyList Auto Update Script
# GitHub: github.com/csznet/proxylist

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置路径
SNIPROXY_CONF="/etc/sniproxy.conf"
DNSMASQ_CONF="/etc/dnsmasq.d/custom_netflix.conf"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GitHub 仓库地址
GITHUB_RAW_URL="https://raw.githubusercontent.com/csznet/proxylist/main"

# 检查是否通过 curl 管道执行（BASH_SOURCE[0] 会是 "bash" 或 "-bash"）
if [[ "${BASH_SOURCE[0]}" == "bash" ]] || [[ "${BASH_SOURCE[0]}" == "-bash" ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
    # 通过 curl 管道执行，使用临时目录
    TEMP_DIR=$(mktemp -d)
    SNIPROXY_SOURCE="$TEMP_DIR/sniproxy.conf"
    DNSMASQ_SOURCE="$TEMP_DIR/dnsmasq.conf"
    USE_GITHUB=1
else
    # 本地执行，使用脚本所在目录
    SNIPROXY_SOURCE="$SCRIPT_DIR/sniproxy.conf"
    DNSMASQ_SOURCE="$SCRIPT_DIR/dnsmasq.conf"
    USE_GITHUB=0
fi

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

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 权限运行此脚本"
        echo "使用命令: sudo $0"
        exit 1
    fi
}

# 从 GitHub 下载配置文件
download_from_github() {
    print_info "从 GitHub 下载配置文件..."

    # 下载 sniproxy.conf
    if curl -fsSL "$GITHUB_RAW_URL/sniproxy.conf" -o "$SNIPROXY_SOURCE"; then
        print_success "已下载: sniproxy.conf"
    else
        print_error "下载失败: sniproxy.conf"
        cleanup_temp
        exit 1
    fi

    # 下载 dnsmasq.conf
    if curl -fsSL "$GITHUB_RAW_URL/dnsmasq.conf" -o "$DNSMASQ_SOURCE"; then
        print_success "已下载: dnsmasq.conf"
    else
        print_error "下载失败: dnsmasq.conf"
        cleanup_temp
        exit 1
    fi
}

# 检查源文件是否存在
check_source_files() {
    local missing_files=0

    # 如果是通过 GitHub 执行，先下载文件
    if [ $USE_GITHUB -eq 1 ]; then
        download_from_github
        return 0
    fi

    # 本地执行，检查文件是否存在
    if [ ! -f "$SNIPROXY_SOURCE" ]; then
        print_error "源文件不存在: $SNIPROXY_SOURCE"
        missing_files=1
    fi

    if [ ! -f "$DNSMASQ_SOURCE" ]; then
        print_error "源文件不存在: $DNSMASQ_SOURCE"
        missing_files=1
    fi

    if [ $missing_files -eq 1 ]; then
        exit 1
    fi
}

# 备份配置文件
backup_config() {
    local config_file=$1
    local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file"
        print_success "已备份: $backup_file"
    else
        print_warning "配置文件不存在，跳过备份: $config_file"
    fi
}

# 替换 SNIProxy 配置
update_sniproxy() {
    print_info "开始更新 SNIProxy 配置..."

    # 备份原配置
    backup_config "$SNIPROXY_CONF"

    # 确保目标目录存在
    local target_dir=$(dirname "$SNIPROXY_CONF")
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        print_info "已创建目录: $target_dir"
    fi

    # 复制新配置
    cp "$SNIPROXY_SOURCE" "$SNIPROXY_CONF"
    print_success "SNIProxy 配置已更新: $SNIPROXY_CONF"

    # 重启 SNIProxy 服务
    restart_sniproxy
}

# 替换 DNSMasq 配置
update_dnsmasq() {
    print_info "开始更新 DNSMasq 配置..."

    # 获取原配置文件中的IP地址
    local original_ip=""
    if [ -f "$DNSMASQ_CONF" ]; then
        # 从原配置文件中提取IP地址（从address=/xxx/IP格式中提取）
        original_ip=$(grep -oP 'address=/[^/]+/\K[0-9.]+' "$DNSMASQ_CONF" | head -1)

        if [ -n "$original_ip" ]; then
            print_info "检测到原配置IP: $original_ip"
        else
            print_warning "无法从原配置中提取IP，将使用默认IP 1.1.1.1"
            original_ip="1.1.1.1"
        fi
    else
        print_warning "原配置文件不存在，将使用默认IP 1.1.1.1"
        original_ip="1.1.1.1"
    fi

    # 备份原配置
    backup_config "$DNSMASQ_CONF"

    # 确保目标目录存在
    local target_dir=$(dirname "$DNSMASQ_CONF")
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        print_info "已创建目录: $target_dir"
    fi

    # 复制并替换IP地址
    if [ "$original_ip" != "1.1.1.1" ]; then
        print_info "正在替换IP地址: 1.1.1.1 -> $original_ip"
        sed "s|/1\.1\.1\.1|/$original_ip|g" "$DNSMASQ_SOURCE" > "$DNSMASQ_CONF"
    else
        cp "$DNSMASQ_SOURCE" "$DNSMASQ_CONF"
    fi

    print_success "DNSMasq 配置已更新: $DNSMASQ_CONF (IP: $original_ip)"

    # 重启 DNSMasq 服务
    restart_dnsmasq
}

# 重启 SNIProxy 服务
restart_sniproxy() {
    print_info "重启 SNIProxy 服务..."

    if systemctl is-active --quiet sniproxy; then
        systemctl restart sniproxy
        if [ $? -eq 0 ]; then
            print_success "SNIProxy 服务已重启"
        else
            print_error "SNIProxy 服务重启失败"
            return 1
        fi
    elif service sniproxy status >/dev/null 2>&1; then
        service sniproxy restart
        if [ $? -eq 0 ]; then
            print_success "SNIProxy 服务已重启"
        else
            print_error "SNIProxy 服务重启失败"
            return 1
        fi
    else
        print_warning "未检测到 SNIProxy 服务，请手动启动"
    fi
}

# 重启 DNSMasq 服务
restart_dnsmasq() {
    print_info "重启 DNSMasq 服务..."

    if systemctl is-active --quiet dnsmasq; then
        systemctl restart dnsmasq
        if [ $? -eq 0 ]; then
            print_success "DNSMasq 服务已重启"
        else
            print_error "DNSMasq 服务重启失败"
            return 1
        fi
    elif service dnsmasq status >/dev/null 2>&1; then
        service dnsmasq restart
        if [ $? -eq 0 ]; then
            print_success "DNSMasq 服务已重启"
        else
            print_error "DNSMasq 服务重启失败"
            return 1
        fi
    else
        print_warning "未检测到 DNSMasq 服务，请手动启动"
    fi
}

# 显示菜单
show_menu() {
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  ProxyList 配置更新工具${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "请选择要执行的操作："
    echo ""
    echo "  1) 仅替换 SNIProxy 配置"
    echo "  2) 仅替换 DNSMasq 配置"
    echo "  3) 替换所有配置（SNIProxy + DNSMasq）"
    echo "  0) 退出"
    echo ""
}

# 清理临时文件
cleanup_temp() {
    if [ $USE_GITHUB -eq 1 ] && [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_info "已清理临时文件"
    fi
}

# 主函数
main() {
    # 检查权限
    check_root

    # 检查源文件
    check_source_files

    # 显示菜单
    show_menu

    # 读取用户选择
    read -p "请输入选项 [0-3]: " choice
    echo ""

    case $choice in
        1)
            update_sniproxy
            print_success "操作完成！"
            ;;
        2)
            update_dnsmasq
            print_success "操作完成！"
            ;;
        3)
            update_sniproxy
            echo ""
            update_dnsmasq
            echo ""
            print_success "所有配置已更新完成！"
            ;;
        0)
            print_info "退出程序"
            cleanup_temp
            exit 0
            ;;
        *)
            print_error "无效的选项，请重新运行脚本"
            cleanup_temp
            exit 1
            ;;
    esac

    # 清理临时文件
    cleanup_temp
}

# 捕获退出信号，确保清理临时文件
trap cleanup_temp EXIT

# 运行主函数
main
