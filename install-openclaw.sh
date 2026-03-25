#!/bin/bash
#============================================
# OpenClaw 统一入口脚本 (自动检测系统)
# 
# 使用方法:
#   Windows (PowerShell):
#     powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/codemaster-agent/openclaw-install/main/install.ps1 | iex"
#   
#   macOS / Linux (Bash):
#     curl -fsSL https://raw.githubusercontent.com/codemaster-agent/openclaw-install/main/install.sh | bash
#
#   或者下载入口脚本后运行:
#     curl -fsSL https://raw.githubusercontent.com/codemaster-agent/openclaw-install/main/install-openclaw.sh | bash
#============================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 打印 banner
show_banner() {
    echo -e "${MAGENTA}"
    echo "========================================"
    echo "  OpenClaw 一键安装脚本"
    echo "  自动检测: Windows / macOS / Linux"
    echo "========================================"
    echo -e "${NC}"
}

# 检测系统并跳转
OS_TYPE=$(uname -s 2>/dev/null || echo "unknown")

if [[ "$OS_TYPE" == "Darwin" ]] || [[ "$OS_TYPE" == "Linux" ]]; then
    # Unix-like 系统
    show_banner
    
    # 下载 Bash 脚本并执行
    SCRIPT_URL="https://raw.githubusercontent.com/codemaster-agent/openclaw-install/main/install.sh"
    
    echo -e "${CYAN}[INFO]${NC} 检测到系统: $OS_TYPE"
    echo -e "${CYAN}[INFO]${NC} 正在下载安装脚本..."
    
    # 检测是否有 curl
    if ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}[WARN]${NC} curl 未安装，尝试使用 wget..."
        if command -v wget &>/dev/null; then
            bash <(wget -qO- "$SCRIPT_URL")
        else
            echo -e "${RED}[ERROR]${NC} 缺少 curl 或 wget，请先安装"
            exit 1
        fi
    else
        bash <(curl -fsSL "$SCRIPT_URL")
    fi

elif [[ "$OS_TYPE" == *"MINGW"* ]] || [[ "$OS_TYPE" == *"CYGWIN"* ]] || [[ "$OS_TYPE" == *"NT"* ]] || [[ -n "$windir" ]]; then
    # Windows 系统 (Git Bash, Cygwin, 或原生 Windows)
    show_banner
    
    echo -e "${CYAN}[INFO]${NC} 检测到系统: Windows"
    echo -e "${CYAN}[INFO]${NC} 正在下载安装脚本..."
    
    # 使用 PowerShell 下载并执行
    PS_SCRIPT_URL="https://raw.githubusercontent.com/codemaster-agent/openclaw-install/main/install.ps1"
    
    powershell -ExecutionPolicy Bypass -Command "irm $PS_SCRIPT_URL | iex"

else
    echo -e "${RED}[ERROR]${NC} 不支持的操作系统: $OS_TYPE"
    exit 1
fi
