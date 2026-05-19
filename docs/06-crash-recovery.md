# 06 — Termux 崩溃恢复策略

> **服务会挂，进程会崩。这不是意外，这是常态。**

Termux 环境有两个层面的崩溃：

1. **进程级崩溃** — Python 脚本 OOM、bash 脚本异常退出
2. **系统级崩溃** — Termux app 被系统杀掉、Android 重启、Termux 升级后进程丢失

## 问题场景

- 你的 AI agent 跑了一天的数据采集，半夜系统更新 → 进程没了
- 编译 whisper.cpp 内存不够 → OOM kill，没来得及保存中间结果
- 网络监控脚本异常退出，保活进程也一起没了

对于端侧 agent，**崩溃不是 if，是 when**。

## 设计原则

1. **崩溃无状态** — 不依赖"进程持续运行中"的任何状态
2. **自动重启** — 系统级监控，进程挂了自动拉起来
3. **检查点** — 长时间运行的任务定期记录进度，重启后从检查点继续

## 方案一：Tasker 监控重启（最简单）

安装 [Tasker](https://play.google.com/store/apps/details?id=net.dinglisch.android.taskerm)：

1. Profile: Event → System → App Changed → App: Termux 关闭
2. Task: 等待 5 秒 → Launch App → Termux → 执行启动脚本

或者在 Tasker 中设置定时任务：

```
每 5 分钟检查一次 Termux 是否在运行
如果不在 → 启动 Termux → 执行 start-agent.sh
```

## 方案二：termux-notification 崩溃感知

在 agent 的核心循环中加入 with-restart：

```bash
#!/data/data/com.termux/files/usr/bin/bash
# agent-wrapper.sh — 自动重启的 agent 启动器

MAX_RESTARTS=5
RESTART_INTERVAL=10
LOG_FILE="$HOME/logs/agent-crash.log"
mkdir -p "$(dirname "$LOG_FILE")"

RESTART_COUNT=0

while [ $RESTART_COUNT -lt $MAX_RESTARTS ]; do
  echo "$(date): 启动 agent (尝试 $((RESTART_COUNT+1))/$MAX_RESTARTS)" >> "$LOG_FILE"
  
  # 你的 agent 主进程
  python agent.py 2>&1 >> "$LOG_FILE"
  
  EXIT_CODE=$?
  echo "$(date): agent 退出, exit_code=$EXIT_CODE" >> "$LOG_FILE"
  
  if [ $EXIT_CODE -eq 0 ]; then
    echo "agent 正常退出，停止重启" >> "$LOG_FILE"
    exit 0
  fi
  
  RESTART_COUNT=$((RESTART_COUNT + 1))
  sleep $RESTART_INTERVAL
done

# 发送通知
termux-notification --title "Agent 崩溃" \
  --content "已尝试重启 ${MAX_RESTARTS} 次，均失败。请检查。" \
  --priority high
```

## 方案三：runit 进程管理器

对于更可靠的需求，Termux 上可以运行 [runit](https://wiki.termux.com/wiki/Runit)：

```bash
pkg install runit
```

配置服务：

```bash
mkdir -p ~/.runit/sv/agent
cat > ~/.runit/sv/agent/run << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec 2>&1
exec python ~/agent.py
EOF
chmod +x ~/.runit/sv/agent/run

# 启动服务
ln -s ~/.runit/sv/agent ~/.runit/service/
```

runit 会自动重启崩溃的服务，且不会产生 zombie 进程。

## 存储管理

端侧空间有限，长时间运行的 agent 要注意：

```bash
# 日志轮转 — 用 logrotate（如果装了）
# 或手动清理 7 天前的日志
find ~/logs -name "*.log" -mtime +7 -delete

# 缓存清理
rm -rf ~/.cache/pip/*
rm -rf ~/.cache/whisper/*

# 查看空间
df -h ~/
du -sh ~/*/ | sort -rh | head -10
```

## 检查清单

- [ ] 核心脚本使用 wrapper 模式自动重启
- [ ] 长时间运行的任务有检查点机制
- [ ] （推荐）runit 守护进程管理
- [ ] 日志轮转已配置
- [ ] 15 秒内自动恢复机制已验证
