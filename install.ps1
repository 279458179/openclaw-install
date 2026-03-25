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

    # 设置代理（如有）
    if ($GitProxy) {
        $env:HTTP_PROXY = $GitProxy
        $env:HTTPS_PROXY = $GitProxy
    }

    # 处理 Conda 环境：先退出去，避免 Conda 劫持 npm
    if ($env:CONDA_PREFIX) {
        Write-Info "检测到 Conda 环境，正在退出..."
        # 记录原 conda 信息后清理
        $env:CONDA_PREFIX = $null
        $env:CONDA_DEFAULT_ENV = $null
        $env:CONDA_PYTHON_EXE = $null
        $env:CONDA_SHLVL = $null
        # 刷新 PATH，移除 conda 路径
        $condaPath = $env:PATH -split ';' | Where-Object { $_ -notmatch 'conda' -and $_ -notmatch 'Anaconda3' -and $_ -notmatch 'Miniconda3' }
        $env:PATH = $condaPath -join ';'
        Write-Ok "已退出 Conda 环境"
    }

    # 确认系统 node/npm 在 PATH 中
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $npmCmd  = Get-Command npm  -ErrorAction SilentlyContinue
    if (-not $nodeCmd -or -not $npmCmd) {
        Write-Err "系统 Node.js 未找到，请先安装 Node.js 18+"
        exit 1
    }
    Write-Info "使用 Node: $(node --version)"
    Write-Info "使用 npm:  $(npm --version)"

    # 设置 npm 镜像
    npm config set registry $NPM_REGISTRY 2>$null

    # 全局安装
    Write-Info "执行: npm i -g openclaw"
    $npmOut = npm i -g openclaw 2>&1
    $npmOut | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Err "npm 安装失败，退出码: $LASTEXITCODE"
        Write-Err "npm 输出: $npmOut"
        exit 1
    }

    Write-Ok "OpenClaw 安装完成"
}

#---- 启动 ----
function Launch-OpenClaw {
    Write-Info "正在启动 OpenClaw..."

    # 清理 Conda 环境变量（如果残留）
    if ($env:CONDA_PREFIX) {
        $env:CONDA_PREFIX = $null
        $env:CONDA_DEFAULT_ENV = $null
        $condaPath = $env:PATH -split ';' | Where-Object { $_ -notmatch 'conda' -and $_ -notmatch 'Anaconda3' -and $_ -notmatch 'Miniconda3' }
        $env:PATH = $condaPath -join ';'
    }

    # 找 openclaw 安装路径
    $openclawPath = $null
    $npmGlobal = npm root -g -q 2>$null
    if ($npmGlobal) {
        $candidate = Join-Path $npmGlobal "openclaw\bin\openclaw.js"
        if (Test-Path $candidate) { $openclawPath = $candidate }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Ok "OpenClaw 启动中..."
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""

    try {
        if ($openclawPath) {
            Write-Info "启动脚本: $openclawPath"
            Start-Process node -ArgumentList $openclawPath -WindowStyle Hidden
        } else {
            Write-Info "直接执行 openclaw 命令"
            Start-Process openclaw -WindowStyle Hidden
        }
        Start-Sleep -Seconds 5
        Start-Process "http://localhost:18789"
    } catch {
        Write-Err "启动失败: $_"
        Write-Info "请手动运行: openclaw"
        Write-Info "或访问: http://localhost:18789"
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
