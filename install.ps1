#============================================
# OpenClaw 一键安装脚本 (Windows PowerShell)
# 使用方法:
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/279458179/openclaw-install/main/install.ps1 | iex"
#   或者保存后以管理员运行: .\install.ps1
#============================================

param(
    [string]$GitProxy = "",      # 可选: http://127.0.0.1:7890
    [switch]$SkipNodeJS          # 跳过 Node.js 安装（如果已安装）
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

#---- 配置 ----
$GITHUB_RAW = "https://raw.githubusercontent.com/279458179/openclaw-install/main"
$NPM_REGISTRY = "https://registry.npmmirror.com"
$NODE_MIRROR = "https://npmmirror.com/mirrors/node"

#---- 颜色 ----
function Write-Info  ($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn  ($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err   ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

#---- 管理员检查 ----
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

#---- 检测 winget ----
function Get-WinGet {
    Get-Command winget -ErrorAction SilentlyContinue
}

#---- 安装 Git ----
function Install-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $ver = git --version
        Write-Ok "Git 已安装 ($ver)"
        return
    }
    Write-Info "正在安装 Git..."

    $winget = Get-WinGet
    if ($winget) {
        # 使用 winget 安装（自动走微软源，速度快）
        winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements --scope machine
    } else {
        # 回退：直接下载 Git for Windows 便携版
        $gitUrl = "https://npmmirror.com/mirrors/git-for-windows/v2.46.0.windows.1/Git-2.46.0-64-bit.tar.bz2"
        $dest = "$env:TEMP\Git-2.46.0-64-bit.tar.bz2"
        $installDir = "$env:ProgramFiles\Git"
        
        Write-Info "正在下载 Git (镜像源)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $gitUrl -OutFile $dest -UseBasicParsing
        
        Write-Info "正在解压..."
        if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
        tar -xjf $dest -C $installDir 2>$null
        
        # 添加到 PATH
        $gitBin = "$installDir\cmd"
        $gitCmd = "$installDir\cmd\git.exe"
        if ((Test-Path $gitCmd) -and ($env:PATH -notlike "*$gitBin*")) {
            [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$gitBin", "Machine")
            $env:PATH += ";$gitBin"
        }
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "Git 安装完成"
}

#---- 安装 Node.js ----
function Install-NodeJS {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $ver = node --version
        Write-Ok "Node.js 已安装 (v$ver)"
        return
    }
    Write-Info "正在安装 Node.js..."

    $winget = Get-WinGet
    if ($winget) {
        winget install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements --scope machine
    } else {
        # 回退：下载 Node.js MSI
        $nodeVersion = "22.12.0"
        $nodeUrl = "$NODE_MIRROR/v$nodeVersion/node-v$nodeVersion-x64.msi"
        $dest = "$env:TEMP\node-v$nodeVersion-x64.msi"
        
        Write-Info "正在下载 Node.js (镜像源)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $nodeUrl -OutFile $dest -UseBasicParsing
        
        Write-Info "正在安装 MSI..."
        Start-Process msiexec -ArgumentList "/i `"$dest`" /quiet /norestart" -Wait -NoNewWindow
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
    
    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    
    # 验证
    Start-Sleep -Seconds 2
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Ok "Node.js 安装完成 ($(node --version))"
    } else {
        Write-Err "Node.js 安装可能失败，请手动检查"
    }
}

#---- 安装 OpenClaw ----
function Install-OpenClaw {
    Write-Info "正在安装 OpenClaw..."

    # 设置 npm 镜像
    npm config set registry $NPM_REGISTRY 2>$null

    # 设置代理（如有）
    if ($GitProxy) {
        npm config set proxy $GitProxy 2>$null
        npm config set https-proxy $GitProxy 2>$null
        $env:HTTP_PROXY = $GitProxy
        $env:HTTPS_PROXY = $GitProxy
    }

    # 全局安装（标准方式）
    Write-Info "执行: npm i -g openclaw"
    npm i -g openclaw 2>&1 | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        Write-Err "npm 安装失败，退出码: $LASTEXITCODE"
        exit 1
    }

    Write-Ok "OpenClaw 安装完成"
}

#---- 启动 ----
function Launch-OpenClaw {
    Write-Info "正在启动 OpenClaw..."

    # 刷新 PATH（确保 npm 全局 bin 在 PATH 中）
    $npmBin = "$env:APPDATA\npm"
    if ($env:PATH -notlike "*$npmBin*") {
        $env:PATH = "$env:PATH;$npmBin"
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$npmBin*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$npmBin", "User")
        }
    }

    # 尝试直接调用 openclaw 命令
    $openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($openclawCmd) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Ok "OpenClaw 启动中..."
        Write-Host "========================================" -ForegroundColor Magenta
        Write-Host ""

        try {
            # 在新窗口后台启动，不阻塞
            Start-Process openclaw -WindowStyle Hidden
            Start-Sleep -Seconds 5
            Start-Process "http://localhost:18789"
        } catch {
            Write-Warn "启动命令失败，尝试 node 直接运行..."
            $npmGlobal = npm root -g -q
            $openclawPath = Join-Path $npmGlobal "openclaw\bin\openclaw.js"
            if (Test-Path $openclawPath) {
                Start-Process node -ArgumentList $openclawPath -WindowStyle Hidden
                Start-Sleep -Seconds 5
                Start-Process "http://localhost:18789"
            }
        }
    } else {
        # 尝试 npm 全局 bin 路径
        $npmGlobal = npm root -g -q
        $openclawPath = Join-Path $npmGlobal "openclaw\bin\openclaw.js"

        if (Test-Path $openclawPath) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Magenta
            Write-Ok "OpenClaw 启动中..."
            Write-Host "========================================" -ForegroundColor Magenta
            Write-Host ""
            Start-Process node -ArgumentList $openclawPath -WindowStyle Hidden
            Start-Sleep -Seconds 5
            Start-Process "http://localhost:18789"
        } else {
            Write-Err "未找到 OpenClaw，请检查安装是否成功"
            exit 1
        }
    }
}

#---- 主流程 ----
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  OpenClaw 一键安装脚本 (Windows)" -ForegroundColor Cyan
    Write-Host "  支持: Windows 10/11" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
    
    $isAdmin = Test-Admin
    if (-not $isAdmin) {
        Write-Warn "建议以管理员身份运行，以安装 Git 和 Node.js 到系统路径"
        Write-Info "继续执行（非管理员模式，部分功能可能受限）..."
        Write-Host ""
    }
    
    Install-Git
    Install-NodeJS
    Install-OpenClaw
    Launch-OpenClaw
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Ok "安装流程完成！"
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "如果浏览器没有自动打开，请手动访问: http://localhost:18789"
    Write-Host ""
    Start-Sleep -Seconds 3
}

Main
