#!/usr/bin/env bash
# ============================================================================
# 卸载 clash-for-linux（mihomo 服务 + 可选 GUI）
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_root

info "停止并移除 mihomo 服务"
systemctl stop mihomo 2>/dev/null || true
systemctl disable mihomo 2>/dev/null || true
rm -f "${SERVICE_FILE}"
rm -rf "${SERVICE_FILE}.d"
systemctl daemon-reload 2>/dev/null || true

info "移除内核二进制"
rm -f "${MIHOMO_BIN}"

info "移除 sysctl 配置"
rm -f /etc/sysctl.d/99-mihomo-tun.conf
sysctl --system >/dev/null 2>&1 || true

# 图形界面（Clash Verge Rev）
if dpkg -s clash-verge >/dev/null 2>&1; then
  info "卸载 Clash Verge Rev"
  apt-get remove -y clash-verge || warn "卸载 GUI 失败，请手动执行：sudo apt remove clash-verge"
fi

read -rp "是否删除配置目录 ${CONFIG_DIR}（含订阅与节点缓存，不可恢复）？[y/N] " ans
case "${ans}" in
  y|Y) rm -rf "${CONFIG_DIR}"; log "已删除 ${CONFIG_DIR}" ;;
  *)   info "保留 ${CONFIG_DIR}" ;;
esac

log "卸载完成"
