#!/usr/bin/env bash
# ============================================================================
# clash-for-linux 一键安装入口
#
#   sudo ./install.sh              # 交互式菜单
#   MODE=cli  sudo -E ./install.sh # 仅命令行内核 + systemd
#   MODE=gui  sudo -E ./install.sh # 仅图形界面 Clash Verge Rev
#   MODE=both sudo -E ./install.sh # 两者都装
#
# 国内网络加速：GH_PROXY=https://ghfast.top/ sudo -E ./install.sh
# ============================================================================
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${MODE:-}"

if [ -z "${MODE}" ]; then
  cat <<'EOF'
============================================================
  clash-for-linux 安装向导（Debian / Ubuntu amd64 为主）
============================================================
  1) 仅命令行模式（mihomo + systemd + 网页面板）
  2) 仅图形界面（Clash Verge Rev）
  3) 两者都安装（推荐：CLI 当服务，GUI 日常操作）
  4) 卸载
============================================================
EOF
  read -rp "请选择 [1-4]: " choice
  case "${choice}" in
    1) MODE="cli" ;;
    2) MODE="gui" ;;
    3) MODE="both" ;;
    4) MODE="uninstall" ;;
    *) echo "无效选择" >&2; exit 1 ;;
  esac
fi

case "${MODE}" in
  cli)       exec bash "${SCRIPT_DIR}/scripts/install-cli.sh" ;;
  gui)       exec bash "${SCRIPT_DIR}/scripts/install-gui.sh" ;;
  both)      bash "${SCRIPT_DIR}/scripts/install-cli.sh"
             bash "${SCRIPT_DIR}/scripts/install-gui.sh" ;;
  uninstall) exec bash "${SCRIPT_DIR}/scripts/uninstall.sh" ;;
  *) echo "未知 MODE：${MODE}（可选 cli / gui / both / uninstall）" >&2; exit 1 ;;
esac
