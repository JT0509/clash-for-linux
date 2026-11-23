# TUN 模式说明

TUN 模式会创建一块虚拟网卡，把系统所有流量（TCP/UDP、含 ICMP）交给 mihomo，
等价于 Clash for Windows 里的 “Tun Mode”。

## 前置条件

| 条件 | 说明 |
|---|---|
| root 权限 | 创建网卡、改路由、写 nftables 规则 |
| `/dev/net/tun` | 大部分云主机/物理机自带；容器内可能没有 |
| `nftables` | `auto-redirect` 使用；`install.sh` 会自动安装 |
| IP 转发 | 脚本写入 `/etc/sysctl.d/99-mihomo-tun.conf` |

检查：

```bash
ls -l /dev/net/tun
sysctl net.ipv4.ip_forward
nft --version
```

## 配置片段

```yaml
tun:
  enable: true
  stack: mixed            # system / gvisor / mixed
  auto-route: true
  auto-detect-interface: true
  auto-redirect: true     # Linux 下用 nftables 重定向
  dns-hijack:
    - any:53
  device: mihomo
  strict-route: false
  mtu: 9000
```

- `stack`：`gvisor` 兼容性最好；`system` 性能高；`mixed` 自动选择（默认）。
- `strict-route: true` 会把局域网流量也强制进 TUN，通常保持 `false`。
- `dns-hijack` 配合上面的 `dns.enhanced-mode: fake-ip` 使用。

## 启动后验证

```bash
# 1. 网卡存在
ip link show mihomo

# 2. 路由/策略路由
ip rule show
ip route show table all | grep -i mihomo || true

# 3. nftables 重定向规则
sudo nft list ruleset | grep -i -E 'mihomo|clash' || true

# 4. 实际连通性
curl -sI --max-time 10 https://www.google.com | head -1
curl -s  --max-time 10 https://api.ipify.org; echo
```

## 关闭 TUN

把配置里的 `tun.enable` 改成 `false`，然后：

```bash
sudo systemctl restart mihomo
```

改用端口代理：应用设置 `http://127.0.0.1:7890`（或环境变量
`http_proxy` / `https_proxy`）。

## 常见问题

- **启动报 `operation not permitted`**：确认 systemd 服务里的
  `AmbientCapabilities` 未被删掉，或用 root 运行。
- **有网卡但上不了网**：先看 `journalctl -u mihomo -n 100`；常见原因是
  DNS 未生效（检查 `dns.enable`）或 `auto-redirect` 与已有防火墙冲突。
- **和 Docker / 其他 VPN 冲突**：关闭对方 TUN，或调整 `strict-route`、
  `route-exclude-address`。
- **GUI 与 CLI 同时开 TUN**：会争抢默认路由。二者只能留一个。
