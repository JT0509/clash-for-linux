# 常见问题排查

## 1. 下载 mihomo / Clash Verge 失败

症状：`curl: (28)`、`Could not resolve host`、长时间卡住。

处理：使用镜像前缀（脚本所有 GitHub 请求都会自动加前缀）：

```bash
GH_PROXY=https://ghfast.top/ sudo -E ./install.sh
```

或指定版本与镜像：

```bash
MIHOMO_VERSION=v1.19.8 GH_PROXY=https://ghfast.top/ sudo -E ./scripts/update-mihomo.sh
```

> 镜像只影响 GitHub 直链；请确保你信任所用镜像。

## 2. mihomo 启动失败

```bash
sudo mihomo -t -f /etc/mihomo/config.yaml     # 先校验配置
journalctl -u mihomo -n 100 --no-pager       # 再看日志
```

常见原因：

| 日志关键字 | 原因 | 处理 |
|---|---|---|
| `yaml: unmarshal errors` | 配置格式错误 | 按提示行号修正 |
| `bind: address already in use` | 端口被占 | 改 `mixed-port` 或停掉冲突程序 |
| `proxy provider error` | 订阅拉取失败 | 检查链接/网络，或改用 `import-subscription.sh` 落地本地文件 |
| `initialize TUN` | 无权限/无 /dev/net/tun | 见 docs/TUN-MODE.md |

## 3. 网页面板打不开 / 401

- 面板地址：`http://127.0.0.1:9090/ui`，需要在本机或 SSH 隧道访问。
- 401 说明配置里设置了 `secret`，登录时填入该值。
- 面板没下载成功：重新执行 `sudo ./scripts/install-cli.sh`，或手动把前端文件放到 `/etc/mihomo/ui`。

SSH 隧道：

```bash
ssh -L 9090:127.0.0.1:9090 user@your-server
```

## 4. 开了 TUN 但无法上网

按顺序检查：

```bash
ip link show mihomo
sysctl net.ipv4.ip_forward
sudo nft list ruleset | grep -i mihomo
journalctl -u mihomo -n 100
```

仍不行时，先临时关闭 TUN，用端口代理验证节点是否可用：

```bash
curl -x http://127.0.0.1:7890 -sI https://www.google.com | head -1
```

- 端口能通 → TUN/路由问题；
- 端口不通 → 订阅/节点问题。

## 5. 订阅导入失败

`import-subscription.sh` 会校验配置后才覆盖旧文件，失败不会破坏现有配置。

- 提示 “base64 节点列表” → 到机场后台把订阅格式切到 **Clash**。
- 提示 “配置校验失败” → 现场保存在 `/tmp/mihomo-config.failed.yaml`。
- 想重置配置：删除 `/etc/mihomo/config.yaml`，然后重新执行
  `sudo ./scripts/import-subscription.sh "<订阅链接>"`。

## 6. Clash Verge Rev（GUI）相关问题

- **TUN 无法开启**：设置里先打开 “Service Mode”，按提示授权；
  再确认服务在跑：`systemctl status clash-verge-service`。
- **与命令行版冲突**：先 `sudo systemctl stop mihomo`。
- **GUI 打不开**：终端运行 `clash-verge` 看报错；缺依赖时
  `sudo apt --fix-broken install`。

## 7. 系统代理不生效（非 TUN）

TUN 关闭时需手动让应用走 7890：

```bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890
```

GUI 用户可在 Clash Verge 里开启 “System Proxy”。

## 8. 卸载重装

```bash
sudo ./scripts/uninstall.sh
# 若保留了 /etc/mihomo，重装后会沿用旧配置
sudo ./install.sh
```
