#!/usr/bin/env bash
# ============================================================================
# 图形界面模式：安装 Clash Verge Rev（开源，GitHub 官方 .deb）
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_root
require_debian
install_deps

arch="$(detect_arch)"
tag="${VERGE_VERSION:-$(latest_tag "${VERGE_REPO}")}"
info "Clash Verge Rev 目标版本：${tag}"

url="$(asset_url "${VERGE_REPO}" "${tag}" "(_${arch}\\.deb$|_x86_64\\.deb$|${arch}\\.deb$)" || true)"
[ -n "${url}" ] || die "未找到 Clash Verge Rev ${tag} 的 ${arch} .deb 安装包"

tmp="$(mktemp -d)"
download "${url}" "${tmp}/clash-verge.deb"
info "安装 .deb（apt 会自动处理依赖）"
apt-get install -y "${tmp}/clash-verge.deb"
rm -rf "${tmp}"

# Clash Verge Rev 的 TUN 需要辅助服务 clash-verge-service
if systemctl list-unit-files 2>/dev/null | grep -q '^clash-verge-service'; then
  systemctl enable --now clash-verge-service >/dev/null 2>&1 || true
  log "已启用 clash-verge-service（TUN/系统代理依赖）"
fi

log "图形界面安装完成（命令：clash-verge）"
cat <<'EOF'

第一次启动：
  1) 应用菜单里打开 “Clash Verge Rev”，或终端运行：clash-verge
  2) 订阅（Profiles）→ 粘贴你的订阅链接 → 导入
  3) 设置（Settings）→ 打开 “Service Mode”（TUN 必需）→ 授权
  4) 首页打开 “Tun Mode” 或 “System Proxy”

注意：
  * 服务端端口默认与 Clash for Windows 一致（混合端口 7890）。
  * 若同时装了命令行版 mihomo，请先停掉：
        sudo systemctl stop mihomo
    两者不要同时开启 TUN，否则路由冲突。
EOF
