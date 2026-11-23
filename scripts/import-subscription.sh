#!/usr/bin/env bash
# ============================================================================
# 导入订阅链接，生成可用的 /etc/mihomo/config.yaml
#
#   sudo ./scripts/import-subscription.sh
#       （推荐：交互式粘贴，输入不回显，不进入 shell 历史）
#   sudo ./scripts/import-subscription.sh "<订阅链接>"
#       （兼容旧用法；参数可能进入 shell 历史 / sudo 日志）
#   sudo ./scripts/import-subscription.sh --url-file FILE --recommended
#       （自动化：从 600 文件读取链接，并强制 TUN + 规则模式）
#
# 兼容两种订阅返回：
#   1) 完整 Clash 配置（含 proxies / proxy-groups / rules）→ 直接作为主配置
#   2) 仅节点列表（含 proxies）                        → 作为本地 provider
# ============================================================================
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# 订阅配置含节点凭证：本脚本新建的文件默认仅 root 可读
umask 077

SUB_URL=""
URL_FILE=""
RECOMMENDED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --url-file)
      URL_FILE="${2:-}"
      [ -n "${URL_FILE}" ] || die "--url-file 需要一个文件路径"
      shift 2
      ;;
    --url-file=*) URL_FILE="${1#*=}"; shift ;;
    --recommended) RECOMMENDED=1; shift ;;
    -h|--help)
      cat <<'EOF'
用法：
  sudo ./scripts/import-subscription.sh
      交互式粘贴订阅链接（推荐；输入不回显）
  sudo ./scripts/import-subscription.sh "<订阅链接>"
      参数方式（会留在 shell 历史和 sudo 日志，不推荐）
  sudo ./scripts/import-subscription.sh --url-file FILE --recommended
      从 600 权限文件读取链接，并套用推荐配置（TUN + 规则模式）
EOF
      exit 0
      ;;
    --*) die "未知参数：$1" ;;
    *)
      [ -z "${SUB_URL}" ] || die "只能提供一个订阅链接"
      SUB_URL="$1"
      shift
      ;;
  esac
done

need_root

if [ -n "${URL_FILE}" ]; then
  [ -r "${URL_FILE}" ] || die "无法读取 URL 文件：${URL_FILE}"
  SUB_URL="$(cat "${URL_FILE}")"
  [ -n "${SUB_URL}" ] || die "URL 文件为空：${URL_FILE}"
elif [ -n "${SUB_URL}" ]; then
  warn "通过命令行参数传入订阅链接可能留在 shell 历史和 sudo 日志中；建议不带参数运行，按提示粘贴。"
elif [ -t 0 ]; then
  read -rsp "请输入订阅链接（输入不回显，不会写入 shell 历史）: " SUB_URL
  echo
else
  die "用法：sudo $0（在终端交互运行，按提示粘贴订阅链接）"
fi
[ -n "${SUB_URL}" ] || die "订阅链接不能为空"
case "${SUB_URL}" in
  https://*) : ;;
  http://*) warn "订阅链接不是 HTTPS，凭证可能以明文传输；建议在机场后台启用 HTTPS。" ;;
  *) die "订阅链接必须以 http:// 或 https:// 开头" ;;
esac
[ -x "${MIHOMO_BIN}" ] || die "未找到 mihomo，请先运行 sudo ./install.sh 选择命令行模式"

tmp="$(mktemp)"
new="$(mktemp)"
curl_cfg=""
trap 'rm -f "${tmp}" "${new}"; if [ -n "${curl_cfg}" ]; then rm -f "${curl_cfg}"; fi' EXIT

# 订阅是账号凭证：只直连订阅服务，绝不经过 GitHub 镜像/第三方代理。
info "下载订阅（仅直连，不经过第三方镜像）"
curl_cfg="$(mktemp)"
chmod 600 "${curl_cfg}"
escaped="$(printf '%s' "${SUB_URL}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
printf 'url = "%s"\n' "${escaped}" > "${curl_cfg}"
if ! curl -fL --retry 2 --retry-delay 1 --connect-timeout 15 --max-time 300 \
     --config "${curl_cfg}" -o "${tmp}"; then
  die "订阅下载失败：请检查链接是否有效、网络是否可达订阅服务（不会把链接发往镜像站）"
fi
rm -f "${curl_cfg}"
curl_cfg=""

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

  # 常见订阅会写 port: 7890；若再追加同端口的 mixed-port 会 bind 冲突。
  # 已存在 mixed-port 时，注释掉使用同一端口的 port / socks-port 行。
  mixed_value="$(awk -F: '/^[[:space:]]*mixed-port:/ {v=$2; gsub(/[^0-9]/, "", v); print v; exit}' "${new}")"
  if [ -n "${mixed_value}" ]; then
    sed -i -E "s/^([[:space:]]*)port:[[:space:]]*${mixed_value}([[:space:]]*(#.*)?)$/# clash-for-linux: mixed-port 已接管 HTTP，原 port 行已注释：\1port: ${mixed_value}\2/" "${new}"
    sed -i -E "s/^([[:space:]]*)socks-port:[[:space:]]*${mixed_value}([[:space:]]*(#.*)?)$/# clash-for-linux: mixed-port 已包含 SOCKS，原 socks-port 行已注释：\1socks-port: ${mixed_value}\2/" "${new}"
  fi

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

if [ "${RECOMMENDED}" = "1" ]; then
  # 新手推荐：规则模式 + TUN 开启
  if grep -qE '^mode:' "${new}"; then
    sed -i -E 's/^mode:[[:space:]]*.*/mode: rule/' "${new}"
  else
    printf '\nmode: rule\n' >> "${new}"
  fi
  info "推荐配置：mode: rule"

  if grep -qE '^external-controller:' "${new}"; then
    sed -i -E 's/^external-controller:[[:space:]]*.*/external-controller: 127.0.0.1:9090/' "${new}"
  fi
  info "推荐配置：external-controller 仅本机"

  # 在 tun: 块内把 enable 改为 true；没有 enable 行则按同缩进插入
  awk '
    BEGIN { in_tun=0; seen=0; ind="" }
    /^tun:[[:space:]]*(#.*)?$/ { in_tun=1; seen=0; ind=""; print; next }
    in_tun {
      if ($0 ~ /^[^[:space:]]/) {
        if (!seen) print (ind == "" ? "  " : ind) "enable: true"
        in_tun=0; seen=0
        print; next
      }
      if (ind == "" && match($0, /^[[:space:]]+/)) ind=substr($0, 1, RLENGTH)
      if ($0 ~ /^[[:space:]]+enable:[[:space:]]*/) {
        sub(/enable:.*/, "enable: true"); print; seen=1; next
      }
      print; next
    }
    { print }
    END { if (in_tun && !seen) print (ind == "" ? "  " : ind) "enable: true" }
  ' "${new}" > "${new}.tmp"
  mv "${new}.tmp" "${new}"
  info "推荐配置：tun.enable: true"
fi

# ---- 校验配置 ----
if ! "${MIHOMO_BIN}" -t -d "${CONFIG_DIR}" -f "${new}"; then
  failed="$(mktemp /tmp/mihomo-config.failed.XXXXXX.yaml)"
  install -m 0600 "${new}" "${failed}"
  die "配置校验失败，现场保留在 ${failed}（600，旧配置未被覆盖）"
fi

install -m 0600 "${new}" "${CONFIG_DIR}/config.yaml"
log "配置已写入 ${CONFIG_DIR}/config.yaml"

if systemctl list-unit-files 2>/dev/null | grep -q '^mihomo.service'; then
  systemctl restart mihomo && log "mihomo 已重启" || warn "重启失败，请查看 journalctl -u mihomo -n 50"
  systemctl is-active --quiet mihomo && log "当前状态：运行中"
else
  info "未安装 systemd 服务，可手动运行：mihomo -d ${CONFIG_DIR} -f ${CONFIG_DIR}/config.yaml"
fi
