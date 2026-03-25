#!/bin/bash
#============================================
# OpenClaw 一键安装脚本 (Windows/macOS/Linux)
# 使用方法: 
#   Windows:    powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/279458179/openclaw-install/main/install.ps1 | iex"
#   macOS/Linux: curl -fsSL https://raw.githubusercontent.com/279458179/openclaw-install/main/install.sh | bash
#============================================

set -e

#---- 配置 ----
GITHUB_RAW_URL="https://raw.githubusercontent.com/279458179/openclaw-install/main"
GITHUB_RAW_URL_RAW="https://raw.githubusercontent.com/279458179/openclaw-install/main"
NPM_REGISTRY="https://registry.npmmirror.com"
NODE_MIRROR="https://npmmirror.com/mirrors/node"
PYTHON_MIRROR="https://npypi.tuna.tsinghua.edu.cn/simple"
APT源="https://mirrors.tuna.tsinghua.edu.cn"
GIT_PROXY=""  # 如果你有代理，设置为 http://127.0.0.1:7890 格式

#---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#---- 检测系统 ----
detect_os() {
    OS_TYPE=$(uname -s)
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        SYSTEM="macOS"
        PKG_MANAGER="brew"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        if command -v apt-get &>/dev/null; then
            SYSTEM="Debian/Ubuntu"
            PKG_MANAGER="apt"
        elif command -v yum &>/dev/null; then
            SYSTEM="CentOS/RHEL"
            PKG_MANAGER="yum"
        elif command -v dnf &>/dev/null; then
            SYSTEM="Fedora"
            PKG_MANAGER="dnf"
        elif command -v pacman &>/dev/null; then
            SYSTEM="Arch"
            PKG_MANAGER="pacman"
        else
            SYSTEM="Linux"
            PKG_MANAGER="unknown"
        fi
    else
        log_error "不支持的操作系统: $OS_TYPE"
        exit 1
    fi
    log_info "检测到系统: $SYSTEM (包管理器: $PKG_MANAGER)"
}

#---- 检查命令是否存在 ----
has_cmd() { command -v "$1" &>/dev/null; }

#---- 安装 Git ----
install_git() {
    if has_cmd git; then
        local ver=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        log_ok "Git 已安装 (版本 $ver)"
        return 0
    fi
    log_info "正在安装 Git..."

    case "$PKG_MANAGER" in
        brew)
            brew install git
            ;;
        apt)
            export DEBIAN_FRONTEND=noninteractive
            # 切换到清华源
            if [ -f /etc/apt/sources.list ]; then
                sudo sed -i "s|http://archive.ubuntu.com|http://mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list 2>/dev/null || true
            fi
            sudo apt-get update -qq
            sudo apt-get install -y -qq git
            ;;
        yum)
            sudo yum install -y git
            ;;
        dnf)
            sudo dnf install -y git
            ;;
        pacman)
            sudo pacman -Sy --noconfirm git
            ;;
        *)
            log_error "无法自动安装 Git，请手动安装后重试"
            exit 1
            ;;
    esac
    log_ok "Git 安装完成"
}

#---- 安装 Node.js ----
install_nodejs() {
    if has_cmd node; then
        local ver=$(node --version 2>/dev/null)
        log_ok "Node.js 已安装 (版本 $ver)"
        return 0
    fi
    log_info "正在安装 Node.js..."

    case "$PKG_MANAGER" in
        brew)
            brew install node
            ;;
        apt|yum|dnf)
            # 使用 nvm 安装，保持用户级
            export NVM_DIR="$HOME/.nvm"
            if [ ! -d "$NVM_DIR" ]; then
                curl -fsSL https://gitee.com/mirrors_nvm/nvm.git/raw/master/install.sh | bash
            fi
            source "$NVM_DIR/nvm.sh" 2>/dev/null || true
            
            # 设置 Node 镜像
            export NVM_NODEJS_ORG_MIRROR="${NODE_MIRROR}"
            
            nvm install --lts 2>/dev/null || nvm install 22 2>/dev/null || {
                # 回退：直接下载
                local NODE_VER="22.12.0"
                local ARCH=$(uname -m)
                [ "$ARCH" == "x86_64" ] && ARCH="x64"
                local FILE="node-v${NODE_VER}-linux-${ARCH}.tar.xz"
                cd /tmp
                curl -fsSL "${NODE_MIRROR}/v${NODE_VER}/${FILE}" -o "$FILE"
                sudo tar -C /usr/local --strip-components=1 -xf "$FILE"
                rm -f "$FILE"
            }
            # 刷新
            export PATH="$HOME/.nvm/versions/node/$(nvm current 2>/dev/null)/bin:$PATH"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm nodejs npm
            ;;
        *)
            # 通用方式：直接下载二进制
            local NODE_VER="22.12.0"
            local ARCH=$(uname -m)
            [ "$ARCH" == "x86_64" ] && ARCH="x64"
            [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] && ARCH="arm64"
            local FILE="node-v${NODE_VER}-linux-${ARCH}.tar.xz"
            cd /tmp
            curl -fsSL "${NODE_MIRROR}/v${NODE_VER}/${FILE}" -o "$FILE"
            sudo tar -C /usr/local --strip-components=1 -xf "$FILE"
            rm -f "$FILE"
            ;;
    esac
    log_ok "Node.js 安装完成 ($(node --version))"
}

#---- 安装 OpenClaw ----
install_openclaw() {
    log_info "正在安装 OpenClaw..."
    
    # 设置 npm 镜像
    npm config set registry "$NPM_REGISTRY" --location=user 2>/dev/null || true
    # 设置 npm 代理（如配置了）
    if [ -n "$GIT_PROXY" ]; then
        npm config set proxy "$GIT_PROXY" 2>/dev/null || true
        npm config set https-proxy "$GIT_PROXY" 2>/dev/null || true
    fi
    
    # 全局安装 openclaw
    npm install -g openclaw --location=user 2>&1 | tail -5
    
    log_ok "OpenClaw 安装完成"
}

#---- 启动 ----
launch_openclaw() {
    log_info "正在启动 OpenClaw..."
    
    # 尝试多种启动方式
    if has_cmd openclaw; then
        echo ""
        echo "========================================"
        log_ok "OpenClaw 启动中..."
        echo "========================================"
        echo ""
        openclaw --doctor 2>/dev/null || openclaw 2>/dev/null || {
            log_warn "直接启动失败，尝试打开浏览器..."
            echo "请手动在浏览器打开: http://localhost:18789"
        }
    else
        # 尝试找安装位置
        local OCLI=$(npm root -g 2>/dev/null)/openclaw/bin/openclaw.js
        if [ -f "$OCLI" ]; then
            echo ""
            echo "========================================"
            log_ok "OpenClaw 启动中..."
            echo "========================================"
            echo ""
            node "$OCLI" 2>/dev/null || {
                log_warn "启动遇到问题，请手动运行: node $OCLI"
            }
        else
            log_error "未找到 OpenClaw 可执行文件"
            exit 1
        fi
    fi
}

#---- 主流程 ----
main() {
    echo ""
    echo "========================================"
    echo "  OpenClaw 一键安装脚本"
    echo "  支持: Windows / macOS / Linux"
    echo "========================================"
    echo ""
    
    detect_os
    install_git
    install_nodejs
    install_openclaw
    launch_openclaw
    
    echo ""
    log_ok "安装流程完成！"
}

main "$@"
