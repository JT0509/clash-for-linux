#!/usr/bin/env bash
# ============================================================================
# clash-for-linux 公共函数库（被其他脚本 source）
# ============================================================================
set -Eeuo pipefail

REPO_SLUG="JT0509/clash-for-linux"
REPO_BRANCH="main"
MIHOMO_REPO="MetaCubeX/mihomo"
VERGE_REPO="clash-verge-rev/clash-verge-rev"

# 固定默认版本：不依赖 GitHub API，适合无加速器环境
DEFAULT_MIHOMO_VERSION="v1.19.34"
DEFAULT_VERGE_VERSION="v2.5.10"
MIHOMO_VERSION="${MIHOMO_VERSION:-}"
VERGE_VERSION="${VERGE_VERSION:-}"

# 可选镜像前缀（依次尝试，留空表示直连）
GH_PROXY="${GH_PROXY:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_DIR="/etc/mihomo"
MIHOMO_BIN="/usr/local/bin/mihomo"
SERVICE_FILE="/etc/systemd/system/mihomo.service"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "请使用 root 或 sudo 运行本脚本"
}

require_debian() {
  [ -r /etc/os-release ] || die "无法识别系统（缺少 /etc/os-release）"
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    debian|ubuntu|linuxmint|pop|kali|deepin|raspbian) : ;;
    *) warn "当前系统为 ${PRETTY_NAME:-未知}，本项目主要面向 Debian/Ubuntu，将继续但可能失败" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armv7l)        echo armv7 ;;
    *) die "不支持的架构：$(uname -m)" ;;
  esac
}

install_deps() {
  export DEBIAN_FRONTEND=noninteractive
  info "安装基础依赖（curl / gzip / iproute2 / nftables / unzip）"
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    ca-certificates curl gzip iproute2 nftables unzip
}

# ---------- 下载：直连 + 多个镜像依次尝试 ----------
mirror_prefixes() {
  printf '%s\n' "" "${GH_PROXY}" "https://gh-proxy.com/" \
    "https://ghfast.top/" "https://ghproxy.net/"
}

download_with_mirrors() {
  local url="$1" out="$2" p cand
  while IFS= read -r p; do
    if [ -z "${p}" ]; then
      cand="${url}"
    else
      cand="${p%/}/${url}"
    fi
    info "下载：${cand}"
    if curl -fL --retry 2 --retry-delay 1 --connect-timeout 15 --max-time 600 \
         -o "${out}" --progress-bar "${cand}"; then
      return 0
    fi
    warn "该通道失败，尝试下一个"
  done < <(mirror_prefixes)
  return 1
}

download() {
  download_with_mirrors "$1" "$2" || die "下载失败：$1"
}

download_optional() {
  download_with_mirrors "$1" "$2" >/dev/null 2>&1
}

# 获取最新 tag，失败时返回默认值
latest_tag() {
  local repo="$1" def="${2:-}" json tag p
  for p in "" "${GH_PROXY}" "https://gh-proxy.com/"; do
    [ -n "${p}" ] && p="${p%/}/"
    json="$(curl -fsSL --connect-timeout 10 --max-time 30 \
      "${p}https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null)" || continue
    tag="$(printf '%s' "${json}" \
      | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')"
    [ -n "${tag}" ] && { printf '%s' "${tag}"; return 0; }
  done
  [ -n "${def}" ] && { printf '%s' "${def}"; return 0; }
  return 1
}

# 优先使用本地仓库文件，其次 GitHub raw，最后 jsDelivr
fetch_repo_file() {
  local rel="$1" dest="$2"
  if [ -f "${REPO_DIR}/${rel}" ]; then
    cp "${REPO_DIR}/${rel}" "${dest}"
    return 0
  fi
  if download_optional \
      "https://raw.githubusercontent.com/${REPO_SLUG}/${REPO_BRANCH}/${rel}" "${dest}"; then
    return 0
  fi
  download "https://cdn.jsdelivr.net/gh/${REPO_SLUG}@${REPO_BRANCH}/${rel}" "${dest}"
}

# 安装 mihomo：优先用仓库内置压缩包（零下载），否则从 release 下载
install_mihomo() {
  local arch tag tmp url asset found=0
  arch="$(detect_arch)"
  tag="${MIHOMO_VERSION:-${DEFAULT_MIHOMO_VERSION}}"
  tmp="$(mktemp -d)"

  local bundled="${REPO_DIR}/bin/mihomo-linux-${arch}.gz"
  if [ -f "${bundled}" ]; then
    info "使用仓库内置内核：${bundled}"
    gzip -t "${bundled}" || { rm -rf "${tmp}"; die "内置内核压缩包损坏"; }
    gzip -dc "${bundled}" > "${tmp}/mihomo"
  else
    info "mihomo 版本：${tag}（${arch}）"
    for asset in \
      "mihomo-linux-${arch}-compatible-${tag}.gz" \
      "mihomo-linux-${arch}-${tag}.gz"; do
      url="https://github.com/${MIHOMO_REPO}/releases/download/${tag}/${asset}"
      if download_with_mirrors "${url}" "${tmp}/mihomo.gz"; then
        found=1
        break
      fi
    done
    if [ "${found}" -ne 1 ]; then
      rm -rf "${tmp}"
      die "内核下载失败。可在有网络的机器下载 ${arch} 版 mihomo 后放到 ${REPO_DIR}/bin/mihomo-linux-${arch}.gz"
    fi
    gzip -dc "${tmp}/mihomo.gz" > "${tmp}/mihomo"
  fi

  install -m 0755 "${tmp}/mihomo" "${MIHOMO_BIN}"
  rm -rf "${tmp}"
  log "mihomo 已安装：$("${MIHOMO_BIN}" -v)"
}

# 开启内核转发，确保 /dev/net/tun（TUN 模式必需）
setup_tun() {
  modprobe tun 2>/dev/null || true
  if [ ! -e /dev/net/tun ]; then
    warn "未发现 /dev/net/tun，TUN 模式可能不可用"
  fi
  cat > /etc/sysctl.d/99-mihomo-tun.conf <<'EOF'
# clash-for-linux: mihomo TUN 模式所需的内核转发
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
  sysctl --system >/dev/null 2>&1 || true
  log "已启用 IP 转发（/etc/sysctl.d/99-mihomo-tun.conf）"
}

install_service() {
  local tmp
  command -v systemctl >/dev/null 2>&1 || die "未检测到 systemd，无法安装服务"
  tmp="$(mktemp)"
  fetch_repo_file "systemd/mihomo.service" "${tmp}"
  install -m 0644 "${tmp}" "${SERVICE_FILE}"
  rm -f "${tmp}"
  systemctl daemon-reload
  systemctl enable mihomo.service >/dev/null
  log "已安装并启用 systemd 服务：mihomo.service"
}

# 可选网页面板（失败不影响代理）
install_dashboard() {
  local tmp
  tmp="$(mktemp -d)"
  install -d "${CONFIG_DIR}/ui"

  if download_optional \
      "https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz" \
      "${tmp}/ui.tgz"; then
    tar -xzf "${tmp}/ui.tgz" -C "${CONFIG_DIR}/ui" 2>/dev/null \
      && log "网页面板 Metacubexd 已安装"
  elif download_optional \
      "https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip" \
      "${tmp}/yacd.zip"; then
    unzip -q "${tmp}/yacd.zip" -d "${tmp}/yacd" 2>/dev/null \
      && cp -r "${tmp}"/yacd/*/ "${CONFIG_DIR}/ui/" 2>/dev/null \
      && log "网页面板 Yacd 已安装"
  else
    warn "网页面板下载失败（不影响代理），可跳过"
  fi

  if [ -f "${CONFIG_DIR}/ui/index.html" ]; then
    info "面板入口：http://127.0.0.1:9090/ui（经 SSH 隧道访问）"
  fi
  rm -rf "${tmp}"
}
