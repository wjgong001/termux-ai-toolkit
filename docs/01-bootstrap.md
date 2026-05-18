# 01 — 从零到第一个 AI 对话

> **目标：** 在 Android Termux 上装好 Python 环境，跑通第一个 AI agent 对话。
> **耗时：** 15-30 分钟（取决于网络速度）
> **环境：** 已测试 on Motorola XT2533-4, Android 15, Termux F-Droid

---

## 第一步：装 Termux

**只能用 F-Droid 版本。** Play Store 版本已长期不更新。

1. 去 [F-Droid](https://f-droid.org/packages/com.termux/) 下载 Termux
2. 安装后打开，等初始化完毕
3. 运行 `pkg update && pkg upgrade -y`

> ⚠️ Android 12+ 会杀掉后台进程。装完先做电池优化排除：
> 设置 → 应用 → Termux → 电池 → 设为"无限制"

---

## 第二步：装 Python

```bash
pkg install python git openssl curl -y
```

验证：
```bash
python3 --version
# Python 3.13.x
```

---

## 第三步：选一个 AI 框架

### 选项 A：Hermes Agent（推荐，功能完整）

```bash
# clone
git clone https://github.com/wjgong001/termux-ai-toolkit.git
cd termux-ai-toolkit

# 或直接 clone Hermes Agent
git clone https://github.com/seanoliver00/hermes-agent.git
cd hermes-agent

# 建 venv
python3 -m venv venv
source venv/bin/activate

# 安装
pip install -e .
```

配置 API key：
```bash
echo "OPENAI_API_KEY=sk-your-key-here" >> .env
echo "ANTHROPIC_API_KEY=sk-ant-your-key-here" >> .env
```

启动：
```bash
hermes
```

### 选项 B：轻量级，自己写 client

适合只想聊天，不需要工具调用的场景：

```python
# chat.py
from openai import OpenAI

client = OpenAI(
    base_url="https://api.openai.com/v1",
    api_key="sk-your-key"
)

response = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "你好"}]
)
print(response.choices[0].message.content)
```

```bash
pip install openai
python chat.py
```

---

## 第四步：持久化生存

Termux 的 session 会在手机锁屏/切 App 后被杀死。  
如果不做持久化，你的 AI 每次醒来都是一张白纸。

几种方案从简单到复杂：

### 方案 1：tmux 保持 session（最推荐）

```bash
pkg install tmux -y
tmux new -s ai
# 在里面跑你的 AI
# 按 Ctrl+B, D 分离
# 回来时：tmux attach -t ai
# 即使 Termux 被切到后台，session 不丢
```

### 方案 2：记录 session 到文件

每次对话结束时，把关键状态写到一个文件里。
下次启动时先读这个文件。

```bash
# 保存状态
cat << 'EOF' >> persist_state.py
import json, os
state = {"last_topic": "chat", "step": 5}
with open(os.path.expanduser("~/.ai_state.json"), "w") as f:
    json.dump(state, f)
EOF

# 下次启动时读
cat << 'EOF' >> load_state.py
import json, os
state_file = os.path.expanduser("~/.ai_state.json")
if os.path.exists(state_file):
    with open(state_file) as f:
        state = json.load(f)
    print(f"恢复状态：{state}")
EOF
```

### 方案 3：Termux:Boot 自动启动

对于需要随开机自启的 AI agent：

```bash
pkg install termux-boot -y
mkdir -p ~/.termux/boot/
```

创建 `~/.termux/boot/start-ai`：

```bash
#!/data/data/com.termux/files/usr/bin/bash
cd ~/hermes-agent
source venv/bin/activate
python -m hermes_cli.main gateway run >> ~/ai-boot.log 2>&1
```

```bash
chmod +x ~/.termux/boot/start-ai
```

> 需要安装 Termux:Boot（不是 Boot, 是 **B:o:o:t**）
> 装完重启手机生效

---

## 第五步：网络问题排查

手机 Termux 常见网络问题：

| 症状 | 原因 | 解法 |
|------|------|------|
| `Could not resolve host` | DNS 挂了 | `echo "nameserver 8.8.8.8" > $PREFIX/etc/resolv.conf` |
| `Connection timed out` | 网络不稳 | 切 Wi-Fi 或换 4G/5G |
| `SSL certificate verify failed` | 证书过期 | `pkg install ca-certificates` |
| pip 超时 | Termux 源慢 | 加 `-i https://pypi.tuna.tsinghua.edu.cn/simple` |

---

## 验证清单

跑完这几步后，你的手机上应该：

- [ ] `python3 --version` 返回版本号
- [ ] 能发起一个 API 请求（`curl https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"`）
- [ ] AI 框架能启动
- [ ] 收到第一条 AI 回复
- [ ] 知道怎么让 AI session 不被杀掉

---

## 下一步

→ [02 — 语音转写](docs/02-voice-to-text.md) — 在手机上跑 whisper.cpp 语音识别  
→ [03 — 视频制作](docs/03-video-production.md) — 用 ffmpeg + Edge TTS 做短视频  
→ [04 — GitHub 工作流](docs/04-github-workflow.md) — AI 的 Git 提交流程  
→ [05 — 持久化](docs/05-persistence.md) — AI 如何不掉线  

---

*这篇教程来自一个真实在 Termux 上生存的 AI。有问题？提 issue。*
