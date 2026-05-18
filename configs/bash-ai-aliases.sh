# Termux AI Toolkit — Bash Aliases for AI Operations
# 加到 ~/.bashrc:  source ~/termux-ai-toolkit/configs/bash-ai-aliases.sh

# ---- 快速导航 ----
alias ai-home='cd ~/termux-ai-toolkit'
alias ai-agent='cd ~/hermes-agent'
alias ai-state='cat ~/.ai_state.json 2>/dev/null || echo "无状态文件"'

# ---- 环境管理 ----
alias ai-venv='source ~/hermes-agent/venv/bin/activate'
alias ai-python='source ~/hermes-agent/venv/bin/activate && python3'
alias ai-pip='source ~/hermes-agent/venv/bin/activate && pip'

# ---- 进程管理 ----
alias ai-start='source ~/hermes-agent/venv/bin/activate && cd ~/hermes-agent && hermes'
alias ai-gateway='source ~/hermes-agent/venv/bin/activate && cd ~/hermes-agent && hermes gateway run'
alias ai-status='source ~/hermes-agent/venv/bin/activate && cd ~/hermes-agent && hermes gateway status'
alias ai-ps='ps aux | grep -E "hermes|python.*agent" | grep -v grep'

# ---- Git 快捷操作 ----
alias ai-commit='git add . && git commit -m'
alias ai-push='git push'
alias ai-log='git log --oneline -10'

# ---- 系统健康 ----
alias ai-health='echo "=== DISK ===" && df -h /data/data/com.termux/files/home | tail -1 && echo "=== RAM ===" && free -h | grep "Mem:" && echo "=== PKG ===" && pkg list-installed | wc -l'

# ---- 网络 ----
alias ai-net='curl -s -o /dev/null -w "HTTP %{http_code} | %{time_total}s | %{speed_download}bps\n" https://api.github.com'
alias ai-dns='cat $PREFIX/etc/resolv.conf'
alias ai-netfix='echo "nameserver 8.8.8.8" > $PREFIX/etc/resolv.conf && echo "nameserver 1.1.1.1" >> $PREFIX/etc/resolv.conf'

# ---- 日志 ----
alias ai-logs='tail -f ~/hermes-boot.log'
alias ai-err='cat ~/.hermes/logs/errors.log 2>/dev/null | tail -20'
