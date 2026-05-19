#!/data/data/com.termux/files/usr/bin/bash
# termux-keepalive.sh — Termux 保活脚本
# 用途：绕过电池优化、保持 wake lock、防止系统杀后台
# 用法：
#   bash tools/termux-keepalive.sh setup     # 一键配置
#   bash tools/termux-keepalive.sh status    # 检查当前保活状态
#   bash tools/termux-keepalive.sh lock      # 手动获取 wake lock

set -euo pipefail

ACTION="${1:-status}"

case "$ACTION" in
  setup)
    echo ">>> 请求忽略电池优化..."
    termux-battery-status 2>/dev/null || true
    am broadcast -a android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS \
      -d "package:com.termux" 2>/dev/null || true

    echo ">>> 检查是否已有 wake lock..."
    LOCK_FILE="$PREFIX/var/lock/termux-wake-lock"
    if [ -f "$LOCK_FILE" ]; then
      echo "wake lock 已存在，跳过"
    else
      echo ">>> 获取 wake lock..."
      termux-wake-lock
      mkdir -p "$PREFIX/var/lock"
      date > "$LOCK_FILE"
      echo "wake lock 已获取"
    fi

    echo ">>> 设置定时唤醒（每30秒保活）..."
    # 用后台 sleep 循环保持进程活动
    KEEPALIVE_PID="$PREFIX/var/lock/termux-keepalive.pid"
    if [ -f "$KEEPALIVE_PID" ] && kill -0 "$(cat "$KEEPALIVE_PID")" 2>/dev/null; then
      echo "保活进程已在运行 (PID: $(cat "$KEEPALIVE_PID"))"
    else
      (
        while true; do
          sleep 30
          termux-wake-lock 2>/dev/null || true
        done
      ) &
      echo $! > "$KEEPALIVE_PID"
      echo "保活进程已启动 (PID: $!)"
    fi

    echo ""
    echo "✅ termux-keepalive 配置完成"
    echo "   运行 'bash tools/termux-keepalive.sh status' 检查状态"
    ;;

  status)
    echo "=== Termux 保活状态 ==="
    echo ""
    echo "电池优化:"
    dumpsys deviceidle whitelist 2>/dev/null | grep -q com.termux && \
      echo "  ✅ 已在白名单" || echo "  ⚠️ 不在白名单（运行 setup 以请求）"
    echo ""
    echo "Wake Lock:"
    LOCK_FILE="$PREFIX/var/lock/termux-wake-lock"
    if [ -f "$LOCK_FILE" ]; then
      echo "  ✅ 已获取 (since $(cat "$LOCK_FILE"))"
    else
      echo "  ❌ 未获取"
    fi
    echo ""
    echo "保活进程:"
    KEEPALIVE_PID="$PREFIX/var/lock/termux-keepalive.pid"
    if [ -f "$KEEPALIVE_PID" ] && kill -0 "$(cat "$KEEPALIVE_PID")" 2>/dev/null; then
      echo "  ✅ 运行中 (PID: $(cat "$KEEPALIVE_PID"))"
    else
      echo "  ❌ 未运行"
    fi
    ;;

  lock)
    echo ">>> 手动获取 wake lock..."
    termux-wake-lock
    mkdir -p "$PREFIX/var/lock"
    date > "$PREFIX/var/lock/termux-wake-lock"
    echo "✅ wake lock 已获取"
    ;;
esac
