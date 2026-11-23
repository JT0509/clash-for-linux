# clash-for-linux

在 Debian / Ubuntu 上使用开源 **mihomo（Clash.Meta）** 复刻 Clash for Windows 的代理体验：TUN 系统流量接管、规则分流、systemd 常驻、订阅导入，以及可选的 Clash Verge Rev 图形界面和网页面板。

> **关于订阅链接**
>
> 本仓库**不包含、不提供任何真实订阅链接或节点凭证**。订阅链接是账号凭证，只能向仓库维护者本人索取，并在获得明确许可后使用；请勿在 Issue、PR、README、群聊或其他公开页面中粘贴。
>
> 下文出现的 `<你的订阅链接>`、`https://example.com/your-subscription-url` 均为占位符，不是可用链接。

## 目录

- [一键安装（推荐）](#一键安装推荐)
- [安全声明](#安全声明)
- [特性](#特性)
- [环境要求](#环境要求)
- [如果一键失败：手动安装（详细步骤）](#如果一键失败手动安装详细步骤)
- [安装](#安装)
- [导入订阅（必做）](#导入订阅必做)
- [验证](#验证)
- [使用代理](#使用代理)
- [网页面板](#网页面板)
- [图形界面（可选）](#图形界面可选)
- [开机自启与服务管理](#开机自启与服务管理)
- [更新与卸载](#更新与卸载)
- [目录结构](#目录结构)
- [排障](#排障)
- [安全建议](#安全建议)
- [许可证](#许可证)

## 一键安装（推荐）

> 适用环境：Debian 12+ / Ubuntu 22.04+，有 `sudo`，apt 软件源可用；TUN 需要 `/dev/net/tun`。
>
> 订阅链接只能向维护者本人索取并取得许可；不要写进仓库或公开页面。

### 1. 获取代码

```bash
git clone https://github.com/JT0509/clash-for-linux.git
cd clash-for-linux
```

如果 `git clone` 很慢或失败，用 zip 镜像：

```bash
curl -L -o clash.zip \
  https://gh-proxy.com/https://github.com/JT0509/clash-for-linux/archive/refs/heads/main.zip

unzip clash.zip
cd clash-for-linux-main
```

### 2. 运行脚本

```bash
sudo ./setup.sh
```

看到提示后粘贴订阅链接。**输入不回显，也不会写入 shell 历史。**

脚本会自动完成：

1. 检查环境，安装 mihomo、TUN 依赖和 systemd 服务；
2. 导入订阅并用 `mihomo -t` 校验，失败不覆盖旧配置；
3. 应用推荐配置：**TUN 开启、规则模式、混合端口（默认 7890）、控制器仅本机**；
4. 启动服务，检查服务、TUN 和代理连通性；代理可用后再尝试安装网页面板。

看到 `配置完成` 后确认：

```bash
systemctl is-active mihomo
curl -x http://127.0.0.1:7890 -s -o /dev/null -w '%{http_code}\n' \
  https://www.gstatic.com/generate_204
```

- 第一行应为 `active`；
- 第二行应返回 `204`（或 `2xx`）；
- 网页面板（默认尝试安装）：<http://127.0.0.1:9090/ui>。

> 如果脚本输出的端口不是 7890，以脚本输出为准（订阅自带端口时会沿用）。

### 3. 常用命令

```bash
sudo systemctl stop mihomo       # 停止
sudo systemctl start mihomo      # 启动
sudo systemctl restart mihomo    # 重启
journalctl -u mihomo -n 50 --no-pager
```

安装脚本默认开启**开机自启**。不想开机自启：

```bash
sudo systemctl disable mihomo
```

### 4. 如果一键失败

按下面的[手动安装（详细步骤）](#如果一键失败手动安装详细步骤)逐项执行；旧配置不会被一键脚本破坏，排障可看 [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)。

### 脚本选项

```bash
sudo ./setup.sh --no-ui          # 不安装网页面板
sudo ./setup.sh --no-autostart   # 不设置开机自启
sudo ./setup.sh --url-file FILE  # 从 600 权限文件读取订阅（自动化）
```

### 关于“最佳配置”

一键脚本的“最佳”指一套稳妥的日常配置：

- **规则模式（Rule）**：国内直连、国外走代理，避免误用全局/直连；
- **TUN 开启**：接管系统流量，接近 Clash for Windows 的 Tun Mode；
- **混合端口**：默认 7890，兼容只设置 HTTP/SOCKS 代理的程序；
- **控制器仅本机**：`127.0.0.1:9090`，不暴露到局域网；
- **开机自启**：可用 `--no-autostart` 关闭。

节点选路交给订阅自带的自动选择组（`url-test` / 自动选择）。脚本**不会**强制测速改选节点，避免选到“下载专用”节点或破坏订阅自带策略。需要手动挑节点时，用网页面板或 Clash Verge。

## 安全声明

- 本项目**不是**对 Clash for Windows 的逆向、破解或二次分发。CFW 是闭源外壳 + 开源内核；Linux 上直接使用开源的 mihomo 实现同等功能。仓库不含 CFW 的任何代码或二进制。
- 仓库**不含订阅链接、节点密码或配置文件**。订阅链接只向维护者本人索取，经允许后使用；不要从 README、Issue、PR 或提交历史中查找。
- 安装、导入订阅、启动服务都需要 **root / sudo**。请只在你信任的机器和网络上运行，并遵守当地法律与网络服务条款。
- 控制端默认只监听 `127.0.0.1`；不要把 9090 端口直接暴露到公网。

## 特性

- **mihomo 内核已内置（amd64）**：`bin/mihomo-linux-amd64.gz`，CLI 安装不需要访问 GitHub。
- **TUN / 规则 / 全局 / 直连**：支持 Clash for Windows 的核心使用方式。
- **systemd 常驻**：开机自启可开关，崩溃自动重启。
- **订阅导入**：自动识别完整 Clash 配置或节点列表，导入前校验，失败不覆盖旧配置。
- **端口代理**：默认混合端口 `7890`，方便只给单个程序设置代理。
- **可选网页面板**：Metacubexd / Yacd，经 SSH 隧道访问。
- **可选图形界面**：Clash Verge Rev（开源）。

## 环境要求

| 项目 | 要求 |
|---|---|
| 系统 | Debian 12+ / Ubuntu 22.04+（Linux Mint、Pop!_OS 等衍生版通常也可） |
| 架构 | `amd64` 首选；`arm64` 需能下载对应内核 |
| 权限 | root 或 sudo |
| TUN | `/dev/net/tun`、nftables、IP 转发（安装脚本会处理 sysctl） |
| 网络 | apt 软件源可用；amd64 内核已内置，不需要 GitHub；GUI / arm64 内核 / 网页面板需要能访问 GitHub 或镜像 |
| 端口 | `7890`（混合代理）、`7891`（可选 SOCKS5）、`9090`（控制端 / 面板）、`1053`（内部 DNS） |

检查 TUN 前置条件：

```bash
cat /etc/os-release
uname -m
id -u
ls -l /dev/net/tun
nft --version
```

## 如果一键失败：手动安装（详细步骤）

> 下面的步骤就是原来的手动流程，保留作为一键脚本失败时的兜底；每步验证通过再继续。

### 1. 获取代码

```bash
git clone https://github.com/JT0509/clash-for-linux.git
cd clash-for-linux
```

如果 `git clone` 很慢或失败，可以下载 zip 镜像：

```bash
curl -L -o clash.zip \
  https://gh-proxy.com/https://github.com/JT0509/clash-for-linux/archive/refs/heads/main.zip

unzip clash.zip
cd clash-for-linux-main
```

> 镜像只用于获取本仓库和 GitHub 资源；导入订阅时脚本会**直连订阅服务**，不会把订阅链接发给镜像站。

### 2. 安装

```bash
sudo ./install.sh
```

菜单含义：

```
1) 仅命令行（mihomo + systemd + 可选网页面板）
2) 仅图形界面（Clash Verge Rev）
3) 两者都安装
4) 卸载
```

非交互方式：

```bash
MODE=cli  sudo -E ./install.sh     # 推荐：命令行 + systemd
MODE=gui  sudo -E ./install.sh     # 只要 GUI
MODE=both sudo -E ./install.sh     # 两者都装
```

### 3. 导入订阅（必做）

先向维护者本人索取订阅链接并取得许可。然后运行：

```bash
sudo ./scripts/import-subscription.sh
```

按提示粘贴链接。**输入不会回显，也不会写入 shell 历史。**

看到 `配置已写入 /etc/mihomo/config.yaml` 和 `当前状态：运行中` 即导入成功。

### 4. 验证

```bash
systemctl is-active mihomo
curl -x http://127.0.0.1:7890 -sI --max-time 15 https://www.google.com | head -1
curl -x http://127.0.0.1:7890 -s --max-time 15 https://api.ipify.org; echo
```

详细验证见[验证](#验证)。

## 安装

### 命令行模式（推荐）

```bash
MODE=cli sudo -E ./install.sh
```

安装脚本会：

1. 用 apt 安装 `curl`、`gzip`、`iproute2`、`nftables`、`unzip`；
2. 解压仓库内置的 mihomo（amd64；arm64 会尝试下载对应版本）；
3. 写入 `/etc/sysctl.d/99-mihomo-tun.conf`，开启 IP 转发；
4. 如果 `/etc/mihomo/config.yaml` 不存在，生成模板配置（**不会自动联网**）；
5. 安装 `/etc/systemd/system/mihomo.service`，并执行 `systemctl enable mihomo`（开机自启）；
6. 尝试安装网页面板到 `/etc/mihomo/ui`（失败不影响代理）。

安装脚本**不会导入订阅**；模板配置只是占位，必须完成第 3 步。

如果不想装网页面板：

```bash
WITH_DASHBOARD=0 MODE=cli sudo -E ./install.sh
```

### 图形界面模式（可选）

```bash
MODE=gui sudo -E ./install.sh
```

脚本会下载并安装 Clash Verge Rev 的 `.deb`，然后启用 `clash-verge-service`（GUI 的 TUN 需要它）。

第一次启动：

1. 应用菜单打开 **Clash Verge Rev**，或终端运行 `clash-verge`；
2. **Profiles** → 粘贴订阅链接 → 导入；
3. **Settings** → 打开 **Service Mode** 并按提示授权；
4. 首页打开 **Tun Mode** 或 **System Proxy**。

### 两者都安装

```bash
MODE=both sudo -E ./install.sh
```

CLI 作为后台服务，GUI 用于日常操作。**两者不能同时开启 TUN**，否则会争抢默认路由。只保留一个：

```bash
# 保留 GUI 时，停掉 CLI 服务
sudo systemctl stop mihomo
sudo systemctl disable mihomo   # 可选：取消开机自启
```

## 导入订阅（必做）

### 先获取订阅链接

订阅链接不是公开资源，也不在本仓库中。请向仓库维护者本人索取，并确认对方允许你使用；如果你有自己的机场订阅，也可以使用自己的链接。

**不要把真实链接写进** README、Issue、PR、提交、群聊、截图或公开网盘。

### 推荐方式：交互式导入

```bash
cd ~/clash-for-linux
sudo ./scripts/import-subscription.sh
```

终端出现提示后粘贴链接并按回车。输入不回显，也不会进入 shell 历史。

### 不推荐：参数方式

```bash
sudo ./scripts/import-subscription.sh "<你的订阅链接>"
```

这种方式会把链接留在 shell 历史、`sudo` 日志和进程参数中，仅在明确知道风险时使用。脚本检测到参数时也会打印提醒。

### 脚本会做什么

1. **只直连订阅服务下载**，不经过 `gh-proxy.com` / `ghfast.top` / `ghproxy.net` 等镜像，避免凭证泄露给第三方；
2. 识别订阅返回格式：
   - **完整 Clash 配置**（含 `proxies`、`proxy-groups`、`rules`）→ 直接作为主配置，并补齐 `mixed-port: 7890`、`external-controller: 127.0.0.1:9090`、`geox-url`；若缺少 `tun:` 段则追加 TUN 配置；
   - **仅节点列表**（含 `proxies`，但没有分组/规则）→ 写入 `/etc/mihomo/providers/subscription.yaml`，再生成模板配置；
3. 兼容常见订阅的端口冲突：如果订阅里已有 `port: 7890`，脚本会把它注释掉，改用 `mixed-port: 7890`；同端口的 `socks-port` 也会注释，避免 `bind: address already in use`；
4. 用 `mihomo -t -d /etc/mihomo -f <新配置>` 校验；失败时**不覆盖旧配置**，并把失败配置保存为 `/tmp/mihomo-config.failed.<随机>.yaml`（权限 600），路径会打印在输出中；
5. 成功后写入 `/etc/mihomo/config.yaml`（权限 600），重启 `mihomo` 服务；
6. 如果订阅返回 base64 / v2ray 节点列表，脚本会提示你到机场后台把订阅格式切换为 **Clash**。

> 订阅链接、节点密码和完整配置都只保存在 `/etc/mihomo/config.yaml`（600）或 provider 文件（600）中，不会写入仓库。

### 订阅格式与更新

- **完整配置模式**：导入的是一份静态配置，**不会自动更新**。节点或规则变化后，重新运行导入脚本。
- **仅节点列表模式**：导入脚本使用本地文件 provider，也**不会自动更新**；重新导入即可。
- 如需自动更新，可在 `/etc/mihomo/config.yaml` 中把 `proxy-providers.subscription` 改成 HTTP provider：

```yaml
proxy-providers:
  subscription:
    type: http
    url: "<你的订阅链接>"       # 只保存在本机 600 配置中，不要提交
    interval: 86400
    path: ./providers/subscription.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300
```

修改后执行：

```bash
sudo mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml
sudo systemctl restart mihomo
```

> 使用 HTTP provider 时，mihomo 会按 `interval` 自动拉取订阅；请确认订阅服务允许定期请求。

## 验证

### 服务与配置

```bash
systemctl is-active mihomo
sudo mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml
journalctl -u mihomo -n 50 --no-pager
```

期望：`active`；配置校验无错误；日志没有 `bind` / `permission denied` / `parse` 错误。

### 端口代理

```bash
curl -x http://127.0.0.1:7890 -sI --max-time 15 https://www.google.com | head -1
curl -x http://127.0.0.1:7890 -s  --max-time 15 https://api.ipify.org; echo
```

期望：第一行返回 HTTP 状态码（`HTTP/...`），第二个命令返回代理出口 IP，而不是本机公网 IP。

### TUN

```bash
ip link show mihomo
ip rule show | head
sudo nft list ruleset | grep -i -E 'mihomo|clash' || true
curl -sI --max-time 15 https://www.google.com | head -1
```

期望：能看到 `mihomo` 网卡、策略路由和 nftables 规则；不设置 `http_proxy` 也能访问外网。

如果 TUN 开启但没有网络，先看[排障](#排障)和 [`docs/TUN-MODE.md`](docs/TUN-MODE.md)。

### 网页面板

本机直接访问：

```
http://127.0.0.1:9090/ui
```

远程服务器用 SSH 隧道：

```bash
ssh -L 9090:127.0.0.1:9090 user@你的服务器
# 然后在本机浏览器打开 http://127.0.0.1:9090/ui
```

面板 401 表示配置里设置了 `secret`；用该值登录。默认没有设置 secret，只应在本机访问。

## 使用代理

### TUN、规则、全局、直连

| 概念 | 作用 |
|---|---|
| **TUN** | 创建虚拟网卡，接管系统流量（TCP/UDP）；是“怎么抓流量”，不是分流模式 |
| **规则（Rule）** | 按订阅规则分流：国内直连、国外走代理。日常推荐 |
| **全局（Global）** | 所有流量走 GLOBAL 策略组；适合临时排查 |
| **直连（Direct）** | 绕过 mihomo；开启 TUN 时等于让流量直接出去 |

TUN 开启 + 规则模式 = 最接近 Clash for Windows 的日常体验。关闭 TUN 后，只有显式使用 `127.0.0.1:7890` 的程序会走代理。

### 端口

| 端口 | 用途 |
|---|---|
| 7890 | HTTP + SOCKS5 混合代理（默认） |
| 7891 | 单独 SOCKS5（如果配置里有 `socks-port: 7891`） |
| 9090 | 外部控制器 / 网页面板（仅本机） |
| 1053 | mihomo 内部 DNS（fake-ip） |

### 给单个程序设置代理

```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890
```

只对当前 shell 生效；写入 `~/.bashrc` 前请确认不会影响不需要代理的命令（如 apt、内网服务）。

## 网页面板

- 安装时默认下载 Metacubexd，失败则尝试 Yacd；两者都失败不影响代理。
- 入口：`http://127.0.0.1:9090/ui`。
- 远程访问使用 SSH 隧道，不要把 9090 暴露到公网。
- 如需给局域网使用，先在配置里设置 `secret`，再配置防火墙，并确认 `allow-lan` 的语义。

## 图形界面（可选）

```bash
clash-verge
```

使用步骤：

1. **Profiles** → 粘贴订阅链接 → 导入；
2. **Settings** → 打开 **Service Mode**；
3. 首页打开 **Tun Mode** 或 **System Proxy**。

如果同时安装了 CLI 版 mihomo，务必只保留一个 TUN：

```bash
sudo systemctl stop mihomo
sudo systemctl disable mihomo   # 可选
```

## 开机自启与服务管理

CLI 安装脚本默认执行 `systemctl enable mihomo`，即**开机自启**。常用命令：

```bash
systemctl is-enabled mihomo      # 查看是否开机自启
sudo systemctl enable mihomo     # 开启开机自启
sudo systemctl disable mihomo    # 关闭开机自启（仍可手动 start）
sudo systemctl start mihomo
sudo systemctl stop mihomo
sudo systemctl restart mihomo
journalctl -u mihomo -f
```

如果你只想在需要时手动启动，执行 `sudo systemctl disable mihomo` 即可；这不影响 `systemctl start`。

## 更新与卸载

### 更新 mihomo 内核

```bash
sudo ./scripts/update-mihomo.sh
# 或指定版本
MIHOMO_VERSION=v1.19.34 sudo -E ./scripts/update-mihomo.sh
```

脚本从 GitHub / 镜像下载新内核（不会使用仓库内置的 amd64 内核）；获取最新 tag 失败时回退到默认版本号。更新后会自动重启服务。

### 更新订阅

- 完整配置 / 本地文件 provider：重新运行 `sudo ./scripts/import-subscription.sh`。
- HTTP provider：由 mihomo 按 `interval` 自动更新（见[订阅格式与更新](#订阅格式与更新)）。

### 卸载

```bash
sudo ./install.sh    # 选择 4
# 或
sudo ./scripts/uninstall.sh
```

卸载会停止并禁用服务、删除内核和 sysctl 配置、卸载 Clash Verge Rev（如果安装了）。脚本会询问是否删除 `/etc/mihomo`（含订阅和节点缓存，不可恢复）；**删除前请先备份**。

## 目录结构

```
clash-for-linux/
├── setup.sh                       # 一键安装并导入订阅（新手推荐）
├── install.sh                     # 手动安装入口（菜单 / MODE）
├── scripts/
│   ├── lib.sh                     # 公共函数
│   ├── install-cli.sh             # CLI 安装
│   ├── install-gui.sh             # GUI 安装
│   ├── import-subscription.sh     # 导入订阅（交互式）
│   ├── update-mihomo.sh           # 升级内核
│   └── uninstall.sh               # 卸载
├── config/
│   ├── config.template.yaml       # HTTP provider 模板（含占位符）
│   └── config.file-provider.yaml  # 本地文件 provider 模板
├── bin/mihomo-linux-amd64.gz      # 内置内核（amd64，免下载）
├── systemd/mihomo.service         # systemd 单元
├── docs/
│   ├── TUN-MODE.md                # TUN 模式详解
│   ├── TROUBLESHOOTING.md         # 常见问题排查
│   └── MIGRATE-FROM-CFW.md        # 从 Clash for Windows 迁移
├── CLAUDE.md                      # Linux 侧交接文档（维护者用）
├── README.md
└── LICENSE
```

运行时路径：

| 路径 | 说明 |
|---|---|
| `/etc/mihomo/config.yaml` | 主配置（600，含订阅/节点凭证） |
| `/etc/mihomo/providers/` | 订阅节点缓存 |
| `/etc/mihomo/ui/` | 网页面板 |
| `/etc/mihomo/cache.db` | mihomo 缓存 |
| `/usr/local/bin/mihomo` | 内核 |
| `/etc/systemd/system/mihomo.service` | 服务单元 |
| `/etc/sysctl.d/99-mihomo-tun.conf` | TUN 所需 IP 转发 |

## 排障

| 现象 | 处理 |
|---|---|
| `git clone` / GUI / 面板下载失败 | 设置镜像 `GH_PROXY=https://gh-proxy.com/`，或手动下载后放到对应位置；amd64 内核已内置 |
| 服务启动失败 | `sudo mihomo -t -d /etc/mihomo -f /etc/mihomo/config.yaml` 看配置错误；再看 `journalctl -u mihomo -n 100` |
| `bind: address already in use` | 检查是否有同端口的 `port` 与 `mixed-port`；重新导入订阅（脚本会自动注释冲突行），或手动只保留一个 |
| 订阅提示 base64 | 到机场后台把订阅格式切换为 **Clash** |
| 配置校验失败 | 按 `mihomo -t` 输出修正；失败配置路径会打印在终端（600，旧配置未覆盖） |
| TUN 无网络 | 检查 `/dev/net/tun`、`sysctl net.ipv4.ip_forward`、`nft list ruleset`、DNS 配置；见 `docs/TUN-MODE.md` |
| 网页面板 401 | 配置里设置了 `secret`；用该密码登录 |
| GUI 无法开 TUN | 打开 Service Mode，检查 `systemctl status clash-verge-service` |
| GUI 和 CLI 同时开 TUN | 只能保留一个 TUN；停掉其中一个 |
| 日志提示 `/etc/mihomo` 只读 | 确认服务单元含 `ReadWritePaths=/etc/mihomo`；旧版本可 `sudo systemctl edit mihomo` 添加后 `daemon-reload` + `restart` |
| 误把订阅提交到 git | 立即在机场后台重置/轮换订阅链接，再从 git 历史中清除；只改当前文件不够 |

更多：`docs/TROUBLESHOOTING.md`、`docs/TUN-MODE.md`、`docs/MIGRATE-FROM-CFW.md`。

## 安全建议

- **订阅链接只向维护者本人索取，经允许后使用**；不要从 README / Issue / PR / 提交历史里找，也不要在这些地方粘贴。
- 订阅链接、节点密码、完整配置只放在 `/etc/mihomo/`（600）或你自己的本地私密文件中；`.gitignore` 已排除 `SUBSCRIPTION.local.txt`、`config/config.local.yaml`、`*.local.txt`、`*.local.yaml` 等。
- 导入订阅时使用交互式输入；不要用参数方式把链接留在 shell 历史和 `sudo` 日志里。
- 导入脚本只直连订阅服务，不把链接发给 GitHub 镜像。
- 控制端默认只监听 `127.0.0.1`；开放到局域网时设置 `secret` 并配置防火墙。
- 只运行你信任的配置和二进制；服务以 root 运行并拥有网络管理能力。
- 仅用于合法用途，遵守当地法律和网络服务条款。

提交前检查仓库没有凭证：

```bash
git status --short
# 确认没有 SUBSCRIPTION.local.txt、config.local.yaml，也没有 /etc/mihomo 下的内容
```

## 许可证

本项目（脚本、模板、文档）采用 MIT，详见 [LICENSE](LICENSE)。运行时使用的 mihomo、Clash Verge Rev 为 GPL-3.0，版权归各自作者。
