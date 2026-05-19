# 05 — Termux 电池优化与后台保活

> **端侧 AI agent 的第一杀手：系统杀进程。**  
> Android 的电池优化（Doze mode、App Standby）会在亮屏后几分钟内杀掉 Termux 后台进程。  
> 这不是 bug，这是 Android 的设计。你必须学会绕过它。

## 问题

你的 AI agent 跑在 Termux 里，但：

- 锁屏后 30 秒 → Termux 进程被 suspend
- 亮屏后 3 分钟 → Termux 进程被 kill
- 重启手机后 → Termux 不会自动启动
- 系统更新后 → 电池优化白名单可能被重置

如果你醒来发现 Termux 进程没了，不是你的代码有 bug——是电池优化杀了它。

## 解法一：忽略电池优化（必须做）

```bash
# 请求系统忽略 Termux 的电池优化
am broadcast -a android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS \
  -d "package:com.termux"
```

系统会弹窗确认。同意后 Termux 进入「不受优化」白名单。

**验证是否生效：**

```bash
dumpsys deviceidle whitelist | grep com.termux
# 如果看到输出，说明已在白名单
```

## 解法二：Wake Lock（防锁屏后休眠）

```bash
# 获取 wake lock — 阻止 CPU 进入深度休眠
termux-wake-lock

# 释放 wake lock
# termux-wake-unlock
```

Wake lock 不是万能的。即使持有 wake lock，系统仍然可能在某些场景下（电量极低、过热）忽略它。

## 解法三：定时唤醒保活

用 `termux-wake-lock` 配合定时 ping/轮询，保持进程不被标记为 idle：

```bash
# 30 秒一次保活
while true; do sleep 30; termux-wake-lock 2>/dev/null || true; done &
```

## 一键配置

这个工具包提供了 `tools/termux-keepalive.sh`：

```bash
bash tools/termux-keepalive.sh setup    # 一键配置
bash tools/termux-keepalive.sh status   # 检查当前状态
bash tools/termux-keepalive.sh lock     # 手动获取 wake lock
```

## 进阶：使用 Termux:Boot 开机自启

如果你安装了 [Termux:Boot](https://wiki.termux.com/wiki/Termux:Boot)：

1. 创建一个脚本 `~/.termux/boot/start-agent.sh`
2. 在里面放你的 agent 启动命令
3. 每次开机后 Termux 会自动执行这个脚本

```bash
#!/data/data/com.termux/files/usr/bin/bash
# ~/.termux/boot/start-agent.sh
termux-wake-lock
# 启动你的 agent
```

但注意：很多国产 ROM 会杀掉 Termux:Boot 的自启权限。这时候你需要去「设置 → 自启动管理」手动打开 Termux 的自启开关。

## 常见 ROM 的特殊处理

| ROM | 额外步骤 |
|-----|---------|
| MIUI（小米） | 设置 → 应用设置 → 应用管理 → Termux → 省电策略 → 无限制 |
| EMUI/Harmony（华为） | 设置 → 应用 → 应用启动管理 → Termux → 关闭「自动管理」→ 全部允许 |
| ColorOS（OPPO） | 设置 → 电池 → 耗电保护 → 应用 → Termux → 关闭「冻结后台」 |
| OneUI（三星） | 设置 → 电池 → 后台使用限制 → 关闭「自适应电池」→ 把 Termux 加入「从不休眠的app」 |

## 检查清单

- [ ] Termux 已加入电池优化白名单
- [ ] 已获取 wake lock
- [ ] 保活进程在运行
- [ ] （可选）Termux:Boot 已安装并配置
- [ ] ROM 自启管理已放行
- [ ] `termux-keepalive.sh status` 输出显示 ✅

## 不适合什么场景

Wake lock 会持续消耗电量。如果你的手机需要撑一整天：
- 不要一直持有 wake lock（只在需要时获取）
- 使用 `termux-wake-unlock` 在空闲时释放
- 考虑用 cron 定时唤醒而不是常驻保活
