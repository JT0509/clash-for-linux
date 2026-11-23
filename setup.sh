#!/usr/bin/env bash
# ============================================================================
# clash-for-linux 一键配置（新手推荐）
#
#   sudo ./setup.sh
#       → 检查环境、安装 mihomo、配置 TUN、导入订阅、启动并验证
#
#   sudo ./setup.sh --no-ui          # 不安装网页面板
#   sudo ./setup.sh --no-autostart   # 不设置开机自启
#   sudo ./setup.sh --url-file FILE  # 从 600 权限文件读取订阅（自动化）
#
# 订阅链接只向维护者本人索取，经允许后使用；不要提交到仓库。
# ============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib.sh"

WITH_DASHBOARD="${WITH_DASHBOARD:-1}"
NO_AUTOSTART=0
URL_FILE_IN=""

usage() {
  cat <<'EOF'
用法：
  sudo ./setup.sh
      交互式输入订阅链接，一键完成安装和配置（推荐）

  sudo ./setup.sh --no-ui
      不安装网页面板

  sudo ./setup.sh --no-autostart
      安装后不设置开机自启（仍可手动 systemctl start mihomo）

  sudo ./setup.sh --url-file FILE
      从权限 600 的文件读取订阅链接（自动化；文件需自行保护）
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-ui) WITH_DASHBOARD=0; shift ;;
    --no-autostart) NO_AUTOSTART=1; shift ;;
    --url-file)
      URL_FILE_IN="${2:-}"
      [ -n "${URL_FILE_IN}" ] || die "--url-file 需要一个文件路径"
      shift 2
      ;;
    --url-file=*) URL_FILE_IN="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数：$1（--help 查看用法）" ;;
  esac
done

need_root
require_debian

cat <<'EOF'
============================================================
  clash-for-linux 一键配置
  将完成：安装 mihomo / TUN / systemd / 导入订阅 / 启动验证
============================================================
EOF

if [ -n "${URL_FILE_IN}" ]; then
  [ -r "${URL_FILE_IN}" ] || die "无法读取 URL 文件：${URL_FILE_IN}"
  if [ "$(stat -c '%a' "${URL_FILE_IN}" 2>/dev/null || true)" != "600" ]; then
    warn "URL 文件权限不是 600，建议执行：chmod 600 ${URL_FILE_IN}"
  fi
  url_file="${URL_FILE_IN}"
  cleanup_url=0
else
  [ -t 0 ] || die "请在终端中运行：sudo ./setup.sh（需要交互输入订阅链接）"
  read -rsp "请输入订阅链接（输入不回显，不会写入 shell 历史）: " SUB_URL
  echo
  [ -n "${SUB_URL}" ] || die "订阅链接不能为空"
  case "${SUB_URL}" in
    https://*) : ;;
    http://*) warn "订阅链接不是 HTTPS，凭证可能以明文传输；建议在机场后台启用 HTTPS。" ;;
    *) die "订阅链接必须以 http:// 或 https:// 开头" ;;
  esac
  url_file="$(mktemp)"
  chmod 600 "${url_file}"
  printf '%s' "${SUB_URL}" > "${url_file}"
  unset SUB_URL
  cleanup_url=1
fi

cleanup() {
  if [ "${cleanup_url}" = "1" ] && [ -n "${url_file:-}" ]; then
    rm -f "${url_file}"
  fi
}
trap cleanup EXIT

info "步骤 1/3：安装 mihomo、TUN 和 systemd 服务"
SETUP_MODE=1 WITH_DASHBOARD=0 bash "${SCRIPT_DIR}/install-cli.sh"

info "步骤 2/3：导入订阅并应用推荐配置（TUN + 规则模式）"
bash "${SCRIPT_DIR}/import-subscription.sh" --url-file "${url_file}" --recommended

if [ "${cleanup_url}" = "1" ]; then
  rm -f "${url_file}"
  cleanup_url=0
fi

if [ "${NO_AUTOSTART}" = "1" ]; then
  systemctl disable mihomo >/dev/null 2>&1 || true
  info "已关闭开机自启（仍可手动 systemctl start mihomo）"
fi

info "步骤 3/3：检查服务、TUN 和代理"
sleep 2
active="$(systemctl is-active mihomo 2>/dev/null || true)"
if [ "${active}" != "active" ]; then
  warn "mihomo 未处于 active（当前：${active:-未知}）"
  warn "查看日志：journalctl -u mihomo -n 50 --no-pager"
  exit 1
fi

tun_state="未检测到"
if ip link show mihomo >/dev/null 2>&1; then
  tun_state="已开启（mihomo 网卡）"
fi

proxy_port="$(awk -F: '/^[[:space:]]*mixed-port:/ {v=$2; gsub(/[^0-9]/, "", v); print v; exit}' \
  "${CONFIG_DIR}/config.yaml" 2>/dev/null || true)"
proxy_port="${proxy_port:-7890}"

http_code=""
for attempt in 1 2 3; do
  http_code="$(curl -x "http://127.0.0.1:${proxy_port}" -s -o /dev/null -w '%{http_code}' \
    --max-time 15 https://www.gstatic.com/generate_204 2>/dev/null || true)"
  case "${http_code}" in
    2*) break ;;
  esac
  if [ "${attempt}" -lt 3 ]; then
    sleep 3
  fi
done
case "${http_code}" in
  2*) proxy_ok=1; proxy_state="正常（HTTP ${http_code}）" ;;
  *)  proxy_ok=0; proxy_state="未通过（HTTP ${http_code:-000}）" ;;
esac

# 网页面板放到最后：此时代理已可用，下载可走本地 mihomo，避免无加速器时卡住
if [ "${WITH_DASHBOARD}" = "1" ]; then
  if [ "${proxy_ok}" = "1" ]; then
    info "安装网页面板（经本地代理下载，失败不影响代理）"
    (
      source "${SCRIPT_DIR}/lib.sh"
      http_proxy="http://127.0.0.1:${proxy_port}" \
      https_proxy="http://127.0.0.1:${proxy_port}" \
      install_dashboard
    ) || warn "网页面板安装失败（不影响代理）"
  else
    warn "代理连通性未通过，跳过网页面板安装"
  fi
fi

if [ "${WITH_DASHBOARD}" = "1" ] && [ -f "${CONFIG_DIR}/ui/index.html" ]; then
  panel_state="http://127.0.0.1:9090/ui"
else
  panel_state="未安装（--no-ui、代理未通过或下载失败）"
fi

cat <<EOF

============================================================
  配置完成
------------------------------------------------------------
  服务状态：${active}
  TUN：${tun_state}
  代理：127.0.0.1:${proxy_port}
  代理连通性：${proxy_state}
  网页面板：${panel_state}
  开机自启：$([ "${NO_AUTOSTART}" = "1" ] && echo "已关闭" || echo "已启用（关闭：sudo systemctl disable mihomo）")
------------------------------------------------------------
  停止：sudo systemctl stop mihomo
  重启：sudo systemctl restart mihomo
  日志：journalctl -u mihomo -n 50 --no-pager
============================================================
EOF

case "${http_code}" in
  2*) : ;;
  *)
    warn "安装已完成，但代理连通性检查未通过；请先看上面的日志命令。"
    exit 2
    ;;
esac
