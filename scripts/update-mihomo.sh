#!/usr/bin/env bash
# ============================================================================
# 升级 mihomo 内核到最新版（或 MIHOMO_VERSION 指定版本）
#   sudo ./scripts/update-mihomo.sh
#   MIHOMO_VERSION=v1.19.8 sudo -E ./scripts/update-mihomo.sh
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_root
# 默认查最新版；查询失败则退回内置默认版本
MIHOMO_VERSION="$(latest_tag "${MIHOMO_REPO}" "${DEFAULT_MIHOMO_VERSION}")"
install_mihomo

if systemctl list-unit-files 2>/dev/null | grep -q '^mihomo.service'; then
  systemctl restart mihomo && log "服务已使用新内核重启" || warn "服务重启失败"
fi
