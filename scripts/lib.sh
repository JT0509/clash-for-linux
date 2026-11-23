#!/usr/bin/env bash
# ============================================================================
# clash-for-linux 公共函数库（被其他脚本 source）
# ============================================================================
set -Eeuo pipefail

REPO_SLUG="JT0509/clash-for-linux"
REPO_BRANCH="main"
MIHOMO_REPO="MetaCubeX/mihomo"
VERGE_REPO="clash-verge-rev/clash-verge-rev"

# 国内网络访问 GitHub 较慢时，可设置镜像前缀，例如：
#   GH_PROXY=https://ghfast.top/ sudo -E ./install.sh
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

gh_url() { printf '%s%s' "${GH_PROXY}" "$1"; }

# 获取仓库最新 release 的 tag（如 v1.19.8）
latest_tag() {
  local repo="$1" json tag
  json="$(curl -fsSL --connect-timeout 15 --max-time 40 \
    "$(gh_url "https://api.github.com/repos/${repo}/releases/latest")")" \
    || die "无法获取 ${repo} 最新版本。国内网络可尝试：GH_PROXY=https://ghfast.top/ sudo -E $0"
  tag="$(printf '%s' "$json" \
    | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -n1 \
    | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "${tag}" ] || die "解析 ${repo} 版本号失败"
  printf '%s' "${tag}"
}

# 在指定 release 中按正则找第一个资产下载地址
asset_url() {
  local repo="$1" tag="$2" re="$3" json url
  json="$(curl -fsSL --connect-timeout 15 --max-time 40 \
    "$(gh_url "https://api.github.com/repos/${repo}/releases/tags/${tag}")")" \
    || return 1
  url="$(printf '%s' "${json}" \
    | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\(https\?[^"]*\)"$/\1/' \
    | grep -E "${re}" | head -n1)"
  [ -n "${url}" ] || return 1
  printf '%s' "${url}"
}

download() {
  local url="$1" out="$2"
  info "下载：${url}"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    -o "${out}" --progress-bar "${url}" || die "下载失败：${url}"
}

# 不报错的下载，返回 0/1，用于可选组件
try_download() {
  local url="$1" out="$2"
  curl -fL --retry 2 --connect-timeout 15 --max-time 180 \
    -o "${out}" --silent --show-error "${url}"
}

# 优先取本地仓库文件，缺失时回退到 GitHub raw
fetch_repo_file() {
  local rel="$1" dest="$2"
  if [ -f "${REPO_DIR}/${rel}" ]; then
    cp "${REPO_DIR}/${rel}" "${dest}"
  else
    download "$(gh_url "https://raw.githubusercontent.com/${REPO_SLUG}/${REPO_BRANCH}/${rel}")" "${dest}"
  fi
}

# 下载并安装 mihomo 内核到 /usr/local/bin/mihomo
install_mihomo() {
  local arch tag url tmp
  arch="$(detect_arch)"
  tag="${MIHOMO_VERSION:-$(latest_tag "${MIHOMO_REPO}")}"
  info "mihomo 目标版本：${tag}"

  # 优先 compatible 构建（兼容老 CPU），没有则用普通构建
  url="$(asset_url "${MIHOMO_REPO}" "${tag}" "mihomo-linux-${arch}-compatible-${tag}\\.gz$" || true)"
  if [ -z "${url}" ]; then
    url="$(asset_url "${MIHOMO_REPO}" "${tag}" "mihomo-linux-${arch}-${tag}\\.gz$" || true)"
  fi
  [ -n "${url}" ] || die "未找到 mihomo ${tag} 的 ${arch} 安装包"

  tmp="$(mktemp -d)"
  download "${url}" "${tmp}/mihomo.gz"
  gzip -dc "${tmp}/mihomo.gz" > "${tmp}/mihomo"
  install -m 0755 "${tmp}/mihomo" "${MIHOMO_BIN}"
  rm -rf "${tmp}"
  log "mihomo 已安装：$("${MIHOMO_BIN}" -v)"
}

# 开启内核转发，并确保 /dev/net/tun 存在（TUN 模式必需）
setup_tun() {
  modprobe tun 2>/dev/null || true
  if [ ! -e /dev/net/tun ]; then
    warn "未发现 /dev/net/tun，TUN 模式可能不可用（请在宿主机/虚拟化平台开启 TUN 设备）"
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

# 可选：下载网页面板（Metacubexd，失败则回退 Yacd）
install_dashboard() {
  local tmp
  tmp="$(mktemp -d)"
  install -d "${CONFIG_DIR}/ui"

  if try_download "https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz" "${tmp}/ui.tgz"; then
    tar -xzf "${tmp}/ui.tgz" -C "${CONFIG_DIR}/ui" 2>/dev/null \
      && log "网页面板 Metacubexd 已安装"
  elif try_download "https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip" "${tmp}/yacd.zip"; then
    unzip -q "${tmp}/yacd.zip" -d "${tmp}/yacd" 2>/dev/null \
      && cp -r "${tmp}"/yacd/*/ "${CONFIG_DIR}/ui/" 2>/dev/null \
      && log "网页面板 Yacd 已安装"
  else
    warn "网页面板下载失败（不影响代理），可稍后手动安装到 ${CONFIG_DIR}/ui"
  fi

  if [ -f "${CONFIG_DIR}/ui/index.html" ]; then
    info "面板入口：http://127.0.0.1:9090/ui（需 SSH 端口转发）"
  fi
  rm -rf "${tmp}"
}
