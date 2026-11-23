#!/usr/bin/env bash
# ============================================================================
# 命令行模式：mihomo 内核 + systemd 服务 + 可选网页面板
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_root
require_debian
install_deps

# 1. 安装内核（已存在则跳过；仓库内置内核，无需联网）
if [ -x "${MIHOMO_BIN}" ] && [ "${FORCE_REINSTALL:-0}" != "1" ]; then
  log "检测到已有内核：$("${MIHOMO_BIN}" -v)，跳过下载（FORCE_REINSTALL=1 可强制重装）"
else
  install_mihomo
fi

# 2. TUN 前置条件
setup_tun

# 3. 配置目录与默认配置
install -d "${CONFIG_DIR}/providers" "${CONFIG_DIR}/ui"
if [ ! -f "${CONFIG_DIR}/config.yaml" ]; then
  if [ -f "${REPO_DIR}/config/config.local.yaml" ]; then
    # 本地私有配置（含订阅链接，已被 .gitignore 排除，不会进入仓库）
    install -m 0600 "${REPO_DIR}/config/config.local.yaml" "${CONFIG_DIR}/config.yaml"
    info "已使用本地私有配置 config/config.local.yaml"
  else
    fetch_repo_file "config/config.template.yaml" "${CONFIG_DIR}/config.yaml"
    chmod 600 "${CONFIG_DIR}/config.yaml"
    info "已生成模板配置，稍后请导入你的订阅链接"
  fi
fi

# 4. systemd 服务
install_service

# 5. 可选网页面板
if [ "${WITH_DASHBOARD:-1}" = "1" ]; then
  install_dashboard
fi

# 6. 尝试启动（配置里已有真实订阅、且不是模板占位符时）
if grep -qE '^(proxies|proxy-providers):' "${CONFIG_DIR}/config.yaml" \
   && ! grep -q 'example.com/your-subscription-url' "${CONFIG_DIR}/config.yaml"; then
  if systemctl restart mihomo; then
    systemctl is-active --quiet mihomo && log "mihomo 已启动并运行"
  else
    warn "mihomo 启动失败，请查看：journalctl -u mihomo -n 50 --no-pager"
  fi
fi

log "命令行模式安装完成"
cat <<EOF

下一步（务必执行，否则只有空模板无法上网）：
  cd ${REPO_DIR}
  sudo ./scripts/import-subscription.sh "<你的订阅链接>"

然后启动并查看状态：
  sudo systemctl restart mihomo
  sudo systemctl status mihomo --no-pager
  journalctl -u mihomo -f

网页面板（若已安装）：
  ssh -L 9090:127.0.0.1:9090 <你的Linux主机>
  浏览器打开 http://127.0.0.1:9090/ui

TUN 模式已在配置中默认开启；若同一台机器稍后安装 GUI，
请勿同时开启两者的 TUN（会争抢路由表）。
EOF
