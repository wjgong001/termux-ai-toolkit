#!/data/data/com.termux/files/usr/bin/bash
# termux-network-monitor.sh — 网络断连自动恢复
# 用途：检测网络连通性，断连时自动重试 Wi-Fi/移动网络
# 用法：
#   bash tools/termux-network-monitor.sh           # 单次检查
#   bash tools/termux-network-monitor.sh watch     # 持续监控（每60秒检查一次）
#   bash tools/termux-network-monitor.sh status    # 显示网络状态

set -euo pipefail

ACTION="${1:-status}"
TARGET="${2:-8.8.8.8}"
LOG_DIR="$HOME/.cache/termux-network-monitor"
mkdir -p "$LOG_DIR"

check_network() {
  local TARGET="$1"
  # ping 一次，超时3秒
  if ping -c 1 -W 3 "$TARGET" >/dev/null 2>&1; then
    echo "ok"
  else
    echo "fail"
  fi
}

show_status() {
  echo "=== Termux 网络状态 ==="
  echo ""
  echo "接口信息:"
  ip addr show 2>/dev/null | grep -E "inet |state " || ifconfig 2>/dev/null | grep -E "inet |status" || echo "  （无网络接口信息）"
  echo ""
  echo "连通性测试 (${TARGET}):"
  if [ "$(check_network "$TARGET")" = "ok" ]; then
    echo "  ✅ 连通"
  else
    echo "  ❌ 不通"
  fi
  echo ""
  echo "DNS:"
  grep -v "^#" /etc/resolv.conf 2>/dev/null | head -3 || echo "  （无 resolv.conf）"
}

repair() {
  local TIMESTAMP
  TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)
  
  echo "[$TIMESTAMP] 网络断开，尝试恢复..."

  # 1. 刷新 DNS 缓存
  ndc resolver flushdefaultif 2>/dev/null || true
  ndc resolver flushif wlan0 2>/dev/null || true

  # 2. 重新获取 IP（Wi-Fi）
  if command -v termux-wifi-connectioninfo &>/dev/null; then
    # 先关闭再打开 Wi-Fi
    termux-wifi-enable false 2>/dev/null || true
    sleep 2
    termux-wifi-enable true 2>/dev/null || true
    sleep 3
  fi

  # 3. 重试3次
  for i in 1 2 3; do
    if [ "$(check_network "$TARGET")" = "ok" ]; then
      echo "[$TIMESTAMP] ✅ 第${i}次重试后恢复"
      echo "$TIMESTAMP:recovered" >> "$LOG_DIR/history.log"
      return 0
    fi
    sleep 2
  done

  echo "[$TIMESTAMP] ❌ 重试3次后仍未恢复"
  echo "$TIMESTAMP:failed" >> "$LOG_DIR/history.log"
  return 1
}

case "$ACTION" in
  status)
    show_status
    ;;

  watch)
    echo ">>> 启动网络监控（每60秒检查一次）..."
    echo "    日志目录: $LOG_DIR"
    echo "    PID: $$"
    echo ""

    FAIL_COUNT=0
    while true; do
      RESULT=$(check_network "$TARGET")
      if [ "$RESULT" = "ok" ]; then
        FAIL_COUNT=0
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        if [ "$FAIL_COUNT" -ge 2 ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') 连续 ${FAIL_COUNT} 次失败，尝试恢复..."
          repair || true
        fi
      fi

      # 每60秒检查，但实际sleep会处理中断
      sleep 60
    done
    ;;

  check|""|*)
    if [ "$(check_network "$TARGET")" = "ok" ]; then
      echo "✅ 网络连通 ($TARGET)"
      exit 0
    else
      echo "❌ 网络不通 ($TARGET)"
      exit 1
    fi
    ;;
esac
