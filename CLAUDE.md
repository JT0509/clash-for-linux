# CLAUDE.md —— Linux 侧交接文档

本仓库在 Windows 侧生成，需要你在本机（Debian/Ubuntu）完成安装、订阅导入和验证。
请按顺序执行，每步验证通过再进入下一步。

仓库地址：

```bash
git clone https://github.com/JT0509/clash-for-linux.git
cd clash-for-linux
```

若 clone 失败，用镜像下载 zip：

```bash
curl -L -o clash.zip https://gh-proxy.com/https://github.com/JT0509/clash-for-linux/archive/refs/heads/main.zip
unzip clash.zip && cd clash-for-linux-main
```

## 背景与约束

- 目标：用开源 **mihomo** 复刻 Clash for Windows 的代理功能（含 TUN）。
- **不要**逆向、复制或分发 Clash for Windows 的任何代码/二进制。
- **不要把订阅链接或节点凭证提交进仓库**。仓库是公开的。
- 用户会单独提供订阅链接；若存在本地文件 `SUBSCRIPTION.local.txt`，可从其中读取。
- 目标机**没有任何加速器**。内核已内置在 `bin/mihomo-linux-amd64.gz`，CLI 安装不需要联网下载内核；只有 GUI 的 `.deb` 和网页面板需要联网（脚本会自动走镜像）。
- 只用于合法用途。

## 环境检查

```bash
cat /etc/os-release
uname -m
id -u
ls -l /dev/net/tun
nft --version
```

要求：Debian/Ubuntu、`amd64`（或 arm64）、有 sudo、`/dev/net/tun` 存在。

## 执行步骤

### 1. 安装

```bash
# 仅命令行（推荐）
MODE=cli sudo -E ./install.sh

# 或用户需要图形界面
MODE=both sudo -E ./install.sh
```

说明：CLI 模式直接解压仓库内置内核，**不会访问 GitHub**。GUI 包下载失败时脚本会自动换镜像；如仍失败，可在有网络的机器下载 `Clash.Verge_2.5.10_amd64.deb` 后 `scp` 到本机执行 `sudo apt install ./Clash.Verge_2.5.10_amd64.deb`。

如 apt 源过慢，可征得用户同意后换成国内镜像（清华/阿里）再继续。

### 2. 导入订阅

向用户索取订阅链接（或读取 `SUBSCRIPTION.local.txt`），然后：

```bash
sudo ./scripts/import-subscription.sh
# 按提示粘贴订阅链接；输入不回显，不进入 shell 历史
```

脚本会自动校验配置并在成功后重启服务。**不要**把链接写入任何被 git 跟踪的文件。

### 3. 验证

```bash
systemctl is-active mihomo
sudo mihomo -t -f /etc/mihomo/config.yaml
journalctl -u mihomo -n 50 --no-pager
curl -x http://127.0.0.1:7890 -sI --max-time 15 https://www.google.com | head -1
curl -x http://127.0.0.1:7890 -s --max-time 15 https://api.ipify.org; echo
```

TUN 验证：

```bash
ip link show mihomo
ip rule show | head
sudo nft list ruleset | grep -i mihomo
```

### 4. 可选组件

- 网页面板：安装时默认下载到 `/etc/mihomo/ui`，访问 `http://127.0.0.1:9090/ui`（SSH 隧道）。
- GUI：需要时执行 `MODE=gui sudo -E ./install.sh`，然后运行 `clash-verge`，
  在 Settings 中开启 Service Mode。GUI 的 TUN 与服务端 CLI 二选一，勿同时开启。

## 验收标准

- [ ] `systemctl is-active mihomo` 输出 `active`
- [ ] `curl -x http://127.0.0.1:7890 ...` 返回 HTTP 状态码（非空、非超时）
- [ ] `ip link show mihomo` 能看到网卡（若启用 TUN）
- [ ] `git status` 无订阅链接/凭证，`git grep -n "你的订阅域名"` 无结果
- [ ] 用户确认可以正常上网

## 失败处理

| 问题 | 处理 |
|---|---|
| GitHub 下载失败 | 脚本会自动尝试 `gh-proxy.com` / `ghfast.top` / `ghproxy.net`；仍失败可设 `GH_PROXY=https://gh-proxy.com/` |
| 内核已内置 | CLI 模式无需下载内核：`bin/mihomo-linux-amd64.gz` |
| 配置校验失败 | 按 `mihomo -t` 输出修正；脚本会打印失败配置的随机路径（600），旧配置未被覆盖 |
| 服务启动失败 | `journalctl -u mihomo -n 100` |
| 订阅是 base64 | 让用户在机场后台切换为 Clash 格式 |
| TUN 不通 | 检查 `/dev/net/tun`、`net.ipv4.ip_forward`、`nft list ruleset` |
| 连续两次失败 | 停止，向用户报告现象与已尝试的命令，不要猜测性改动 |

## 禁止事项

- 不得提交 `SUBSCRIPTION.local.txt`、`config/config.local.yaml`、`/etc/mihomo/` 下任何内容。
- 不得为了让服务“看起来正常”而关闭校验或使用假节点。
- 不得修改 `install.sh` 的下载源为不可信第三方，除非用户明确要求。

## 汇报格式

完成后用不超过 10 行汇报：完成的步骤、关键验证命令及输出、遇到的问题、下一步建议。
