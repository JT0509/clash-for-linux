# 从 Clash for Windows 迁移

## 为什么不需要“逆解”

Clash for Windows（CFW）本质是 **Electron 图形外壳 + Clash 内核**：

- 真正处理代理、规则、TUN 的是内核（开源项目 Clash / mihomo）；
- CFW 的外壳是闭源的，但 Linux 上我们直接用**开源的 mihomo + Clash Verge Rev** 即可获得
  相同的代理能力，无需、也不应复制或反编译闭源外壳。

本项目因此**不包含 CFW 的任何代码或二进制**，只复用你自己的订阅数据。

## 获取你的订阅链接（Windows 侧）

任选其一：

1. 打开 CFW → **Profiles** → 在配置上点右键 → **Copy URL**。
2. 打开文件
   `D:\Program Files (x86)\clash\Clash.for.Windows\data\profiles\list.yml`，
   里面 `url:` 后面就是订阅链接（形如 `https://.../link/xxxx?clash=3`）。

> 本仓库**不包含任何订阅链接**。请使用维护者单独提供的链接（`SUBSCRIPTION.local.txt`），或你自己的订阅。

## 在 Linux 侧导入

```bash
cd clash-for-linux
sudo ./scripts/import-subscription.sh "你的订阅链接"
```

脚本会自动识别：

- **完整 Clash 配置**（含 proxies / proxy-groups / rules）→ 直接使用并补上 TUN；
- **仅节点列表** → 生成本地 provider + 模板配置。

导入前会执行 `mihomo -t` 校验，失败不会覆盖旧配置。

## 直接复用 CFW 的配置文件（可选）

CFW 的 `data/profiles/<数字>.yml` 是一份已展开的完整 Clash 配置。
可以直接复制到 Linux：

```bash
sudo install -m 600 从Windows拷来的.yml /etc/mihomo/config.yaml
sudo mihomo -t -f /etc/mihomo/config.yaml
```

若该文件没有 `tun:` 段，按 `docs/TUN-MODE.md` 追加即可。

## 功能对照

| Clash for Windows | 本项目 |
|---|---|
| Profiles / 订阅 | `proxy-provider`，自动定时更新 |
| Tun Mode | `tun.enable` + `auto-route` + `auto-redirect` |
| System Proxy | GUI “System Proxy” 或环境变量 |
| 混合端口 | `mixed-port: 7890` |
| 外部控制 | `external-controller: 127.0.0.1:9090` |
| DNS fake-ip | `dns.enhanced-mode: fake-ip` |
| 规则 / 策略组 | `rules` / `proxy-groups` |

## 注意

- 你的订阅是账号凭证，若仓库公开请谨慎；本仓库内置的是**免费公开线路**，额度共享。
- 迁移后 Windows 侧的 CFW 可以继续保留，两边互不影响。
