# CLAUDE.md —— Linux 侧交接文档

本仓库在 Windows 侧生成，需要你在本机（Debian/Ubuntu）完成安装、订阅导入和验证。
请按顺序执行，每步验证通过再进入下一步。

## 背景与约束

- 目标：用开源 **mihomo** 复刻 Clash for Windows 的代理功能（含 TUN）。
- **不要**逆向、复制或分发 Clash for Windows 的任何代码/二进制。
- **不要把订阅链接或节点凭证提交进仓库**。仓库是公开的。
- 用户会单独提供订阅链接；若存在本地文件 `SUBSCRIPTION.local.txt`，可从其中读取。
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

国内网络下载失败时：

```bash
GH_PROXY=https://ghfast.top/ MODE=cli sudo -E ./install.sh
```

### 2. 导入订阅

向用户索取订阅链接（或读取 `SUBSCRIPTION.local.txt`），然后：

```bash
sudo ./scripts/import-subscription.sh "<订阅链接>"
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
  在 Settings 中开启 Service Mode。

## 验收标准

- [ ] `systemctl is-active mihomo` 输出 `active`
- [ ] `curl -x http://127.0.0.1:7890 ...` 返回 HTTP 状态码（非空、非超时）
- [ ] `ip link show mihomo` 能看到网卡（若启用 TUN）
- [ ] `git status` 无订阅链接/凭证，`git grep -n "你的订阅域名"` 无结果
- [ ] 用户确认可以正常上网

## 失败处理

| 问题 | 处理 |
|---|---|
| GitHub 下载失败 | `GH_PROXY=https://ghfast.top/` 重试 |
| 配置校验失败 | 按 `mihomo -t` 输出修正；现场在 `/tmp/mihomo-config.failed.yaml` |
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
