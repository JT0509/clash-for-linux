#!/usr/bin/env bash
# ============================================================================
# 导入订阅链接，生成可用的 /etc/mihomo/config.yaml
#
#   sudo ./scripts/import-subscription.sh "<订阅链接>"
#
# 兼容两种订阅返回：
#   1) 完整 Clash 配置（含 proxies / proxy-groups / rules）→ 直接作为主配置
#   2) 仅节点列表（含 proxies）                        → 作为本地 provider
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

need_root

SUB_URL="${1:-}"
[ -n "${SUB_URL}" ] || die "用法：sudo $0 \"<订阅链接>\""
[ -x "${MIHOMO_BIN}" ] || die "未找到 mihomo，请先运行 sudo ./install.sh 选择命令行模式"

tmp="$(mktemp)"
new="$(mktemp)"
trap 'rm -f "${tmp}" "${new}"' EXIT

download "${SUB_URL}" "${tmp}"

# ---- 内容识别 ----
if grep -qE '^[[:space:]]*proxies:' "${tmp}"; then
  :
elif grep -qE '^(dm1lc3M|c3M6Ly|dHJvamFu|dmxlc3M|c3Ryb2tlfHZtZXNzK' "${tmp}"; then
  die "订阅返回的是 base64 节点列表（v2ray 格式）。请到机场后台把订阅格式切换为 Clash，再重试。"
else
  die "订阅内容无法识别（未找到 proxies 段）。请确认链接有效且返回 Clash 配置。"
fi

install -d "${CONFIG_DIR}/providers"

if grep -qE '^[[:space:]]*proxy-groups:' "${tmp}" && grep -qE '^[[:space:]]*rules:' "${tmp}"; then
  # ---------- 情况 1：完整配置 ----------
  info "检测到完整 Clash 配置，直接作为主配置使用"
  cp "${tmp}" "${new}"

  ensure_top_key() {
    local key="$1" fallback="$2"
    grep -qE "^${key}:" "${new}" || printf '%s\n' "${fallback}" >> "${new}"
  }

  ensure_top_key "mixed-port" "mixed-port: 7890"
  ensure_top_key "external-controller" "external-controller: 127.0.0.1:9090"
  ensure_top_key "geox-url" "$(cat <<'EOF'
geox-url:
  geoip: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb"
EOF
)"

  if ! grep -qE '^tun:' "${new}"; then
    info "配置中无 tun 段，追加 TUN 模式设置"
    cat >> "${new}" <<'EOF'

# ---- 由 clash-for-linux 追加：TUN 模式 ----
tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  auto-redirect: true
  dns-hijack:
    - any:53
  device: mihomo
  strict-route: false
  mtu: 9000
EOF
  fi
else
  # ---------- 情况 2：仅节点列表 ----------
  info "检测到节点列表，写入本地 provider 并生成模板配置"
  install -m 0600 "${tmp}" "${CONFIG_DIR}/providers/subscription.yaml"
  fetch_repo_file "config/config.file-provider.yaml" "${new}"
fi

# ---- 校验配置 ----
if ! "${MIHOMO_BIN}" -t -f "${new}"; then
  cp "${new}" /tmp/mihomo-config.failed.yaml
  die "配置校验失败，现场保留在 /tmp/mihomo-config.failed.yaml（旧配置未被覆盖）"
fi

install -m 0600 "${new}" "${CONFIG_DIR}/config.yaml"
log "配置已写入 ${CONFIG_DIR}/config.yaml"

if systemctl list-unit-files 2>/dev/null | grep -q '^mihomo.service'; then
  systemctl restart mihomo && log "mihomo 已重启" || warn "重启失败，请查看 journalctl -u mihomo -n 50"
  systemctl is-active --quiet mihomo && log "当前状态：运行中"
else
  info "未安装 systemd 服务，可手动运行：mihomo -d ${CONFIG_DIR} -f ${CONFIG_DIR}/config.yaml"
fi
