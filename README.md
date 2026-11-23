# clash-for-linux

在 Debian / Ubuntu 上使用开源 **mihomo（Clash.Meta）** 内核复刻 Clash for Windows 的代理功能，支持 TUN 全局代理、订阅自动更新、systemd 常驻，以及可选的 Clash Verge Rev 图形界面。

## 说明

- 本项目**不是**对 Clash for Windows 的逆向或破解。CFW 是闭源外壳 + 开源内核，Linux 上直接用开源 mihomo 实现同等功能。仓库不含 CFW 的任何代码或二进制。
- 仓库**不含订阅链接或节点凭证**。订阅链接由维护者单独提供（本地 `SUBSCRIPTION.local.txt`，已被 `.gitignore` 排除），安装后导入即可。
- 仅用于合法用途，遵守当地法律。

## 环境要求

- Debian 12+ / Ubuntu 22.04+，`amd64`（兼容 `arm64`）
- root 或 sudo
- TUN 模式需 `/dev/net/tun` 与 nftables
- 网络：能 `git clone` 即可；**内核已内置**（`bin/mihomo-linux-amd64.gz`），安装时无需下载 Release

## 快速开始

```bash
git clone https://github.com/JT0509/clash-for-linux.git
cd clash-for-linux
sudo ./install.sh
```

菜单：

```
1) 仅命令行（mihomo + systemd + 网页面板）
2) 仅图形界面（Clash Verge Rev）
3) 两者都安装
4) 卸载
```

非交互：

```bash
MODE=cli  sudo -E ./install.sh
MODE=gui  sudo -E ./install.sh
MODE=both sudo -E ./install.sh
```

### 没有加速器 / 网络受限

- CLI 模式的内核已随仓库分发，**不会下载内核**。
- GUI 的 `.deb` 由脚本自动尝试 `gh-proxy.com`、`ghfast.top`、`ghproxy.net` 镜像。
- `git clone` 本身很慢或失败时，用镜像下 zip：

```bash
curl -L -o clash.zip https://gh-proxy.com/https://github.com/JT0509/clash-for-linux/archive/refs/heads/main.zip
unzip clash.zip && cd clash-for-linux-main
```

- 也可手动指定镜像：`GH_PROXY=https://gh-proxy.com/ MODE=cli sudo -E ./install.sh`

### 导入订阅（必做）

安装完成后导入你的订阅链接：

```bash
sudo ./scripts/import-subscription.sh "<你的订阅链接>"
```

脚本会自动识别「完整 Clash 配置」或「仅节点列表」，导入前用 `mihomo -t` 校验，失败不覆盖旧配置，成功后自动重启服务。

### 命令行模式验证

```bash
systemctl status mihomo --no-pager
journalctl -u mihomo -f
curl -x http://127.0.0.1:7890 -sI https://www.google.com | head -1
```

网页面板（SSH 隧道）：

```bash
ssh -L 9090:127.0.0.1:9090 user@你的服务器
# 浏览器打开 http://127.0.0.1:9090/ui
```

### 图形界面模式

```bash
clash-verge          # 或从应用菜单打开
```

1. Profiles → 粘贴订阅链接 → 导入
2. Settings → 开启 Service Mode（TUN 必需）
3. 首页开启 Tun Mode 或 System Proxy

### 两者同时安装

CLI 作后台服务，GUI 作日常操作。**两者不能同时开 TUN**：

```bash
sudo systemctl stop mihomo
sudo systemctl disable mihomo   # 可选
```

## 端口

| 端口 | 用途 |
|---|---|
| 7890 | HTTP + SOCKS5 混合代理 |
| 7891 | 单独 SOCKS5 |
| 9090 | 外部控制器 / 网页面板 |
| 1053 | mihomo 内部 DNS（fake-ip） |

系统级代理：

```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890
```

## TUN 模式

默认配置已开启（`tun.enable: true`，`auto-route` + `auto-redirect` + `dns-hijack`）。
关闭：把 `enable` 改为 `false` 后重启服务，改用 7890 端口代理。

详细说明与验证：`docs/TUN-MODE.md`。

## 常用命令

```bash
sudo systemctl status mihomo
sudo systemctl restart mihomo
sudo systemctl stop mihomo
journalctl -u mihomo -f

sudo mihomo -t -f /etc/mihomo/config.yaml    # 校验配置
sudo ./scripts/update-mihomo.sh              # 升级内核
sudo ./scripts/uninstall.sh                  # 卸载

curl -x http://127.0.0.1:7890 -sI https://www.google.com | head -1
```

## 目录结构

```
clash-for-linux/
├── install.sh                     # 一键安装入口
├── scripts/
│   ├── lib.sh                     # 公共函数
│   ├── install-cli.sh             # CLI 安装
│   ├── install-gui.sh             # GUI 安装
│   ├── import-subscription.sh     # 导入订阅
│   ├── update-mihomo.sh           # 升级内核
│   └── uninstall.sh               # 卸载
├── config/
│   ├── config.template.yaml       # HTTP provider 模板
│   └── config.file-provider.yaml  # 本地文件 provider 模板
├── bin/mihomo-linux-amd64.gz      # 内置内核（v1.19.34，免下载）
├── systemd/mihomo.service
├── docs/
│   ├── TUN-MODE.md
│   ├── TROUBLESHOOTING.md
│   └── MIGRATE-FROM-CFW.md
├── CLAUDE.md                      # 给 Linux 侧 Claude Code 的交接文档
└── README.md
```

运行时路径：

| 路径 | 说明 |
|---|---|
| `/etc/mihomo/config.yaml` | 主配置（600） |
| `/etc/mihomo/providers/` | 订阅节点缓存 |
| `/etc/mihomo/ui/` | 网页面板 |
| `/usr/local/bin/mihomo` | 内核 |
| `/etc/systemd/system/mihomo.service` | 服务单元 |

## 排障

| 现象 | 处理 |
|---|---|
| 下载失败 | 设置 `GH_PROXY` 镜像后重试 |
| 服务启动失败 | `sudo mihomo -t -f /etc/mihomo/config.yaml`，再看 `journalctl -u mihomo -n 100` |
| TUN 无网络 | 检查 `/dev/net/tun`、`net.ipv4.ip_forward`、`nft list ruleset` |
| 网页面板 401 | 配置中 `secret` 的值即登录密码 |
| 订阅提示 base64 | 到机场后台把订阅格式切换为 Clash |
| GUI 开不了 TUN | 开启 Service Mode：`systemctl status clash-verge-service` |

更多：`docs/TROUBLESHOOTING.md`。

## 安全

- 控制端默认只监听 `127.0.0.1`；开放到局域网时务必设置 `secret` 并配置防火墙。
- 不要提交订阅链接：`config/config.local.yaml`、`SUBSCRIPTION.local.txt` 已被 `.gitignore` 排除。
- 定期升级内核：`sudo ./scripts/update-mihomo.sh`。

## 许可证

本项目（脚本、模板、文档）采用 MIT。运行时下载的 mihomo、Clash Verge Rev 为 GPL-3.0，版权归各自作者。详见 [LICENSE](LICENSE)。
