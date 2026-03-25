# OpenClaw 一键安装脚本

一句命令，自动安装 OpenClaw 最新版本及全部依赖（Git、Node.js），支持 Windows / macOS / Linux。

---

## 🚀 一键安装

### Windows

```powershell
# 标准安装（每步自动实时显示）
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/279458179/openclaw-install/main/install.ps1 | iex"

# 开启详细模式（显示更多调试信息）
$env:OPENCLAW_VERBOSE="1"; powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/279458179/openclaw-install/main/install.ps1 | iex"
```

> 如果你使用 Git Bash 或 WSL，也可以用：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/279458179/openclaw-install/main/install.sh | bash
> ```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/279458179/openclaw-install/main/install.sh | bash
```

---

## ✅ 安装过程

脚本会自动检测你的系统，执行以下步骤：

1. **检测操作系统** — 自动识别 Windows / macOS / Linux
2. **安装 Git** — 如未安装，自动安装
3. **安装 Node.js** — 自动安装 LTS 版本
4. **安装 OpenClaw** — 通过 npm 全局安装
5. **启动 OpenClaw** — 安装完成后自动启动 onboard 界面

---

## 🌐 国内网络优化

脚本内置以下优化，无需手动配置：

| 组件 | 镜像源 |
|------|--------|
| npm packages | npmmirror (阿里) |
| Node.js 二进制 | npmmirror (阿里) |
| Ubuntu apt 源 | 清华镜像 |
| Git for Windows | npmmirror |

---

## 🔧 代理配置（可选）

如果你需要通过代理访问外网：

### Windows (PowerShell)
```powershell
$GitProxy = "http://127.0.0.1:7890"
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/279458179/openclaw-install/main/install.ps1 | iex" -GitProxy $GitProxy
```

### macOS / Linux (Bash)
```bash
export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"
curl -fsSL https://raw.githubusercontent.com/279458179/openclaw-install/main/install.sh | bash
```

---

## 📋 系统要求

- **Windows**: Windows 10/11，PowerShell 5+
- **macOS**: macOS 10.15+
- **Linux**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+ / Arch Linux

---

## 🔍 安装后验证

安装完成后，脚本会自动打开浏览器访问 onboard 界面。你也可以手动访问：

- **Web UI**: http://localhost:18789
- **健康检查**: `openclaw --doctor`

---

## 📚 相关链接

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [ClawHub (插件市场)](https://clawhub.com)

---

## ⚠️ 常见问题

**Q: 安装脚本报错 "无法连接"**
A: 请检查网络连接，或配置代理（见上方「代理配置」）

**Q: Node.js 安装失败**
A: 脚本会自动尝试多个安装方式。如果仍失败，请手动安装 Node.js 18+ 后重新运行脚本

**Q: 安装完成但浏览器没反应**
A: 请手动访问 http://localhost:18789

---

*一键安装，省时省力。*
