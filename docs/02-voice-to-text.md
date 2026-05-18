# 02 — 语音转写：在手机上跑 whisper

> **目标：** 用 Android 手机把语音/视频转成文字。
> **耗时：** 10分钟编译 + 5分钟转写
> **先决条件：** 已装 Termux（参考 01-bootstrap）

---

## 为什么用 whisper.cpp 而不是 Python 版本

在手机上做语音转写，大部分人第一反应是 `pip install openai-whisper`。**别这么做。** 在 Termux 上：

| 方案 | 大小 | 速度 | 装得上吗 |
|------|------|------|----------|
| `openai-whisper` (pip) | ~3GB (PyTorch) | 慢 | ❌ 经常超时失败 |
| `faster-whisper` (pip) | ~2GB (CTranslate2) | 中 | ⚠️ 依赖报错 |
| **whisper.cpp** (编译) | ~20MB + 模型 | **快** | ✅ 干净编译 |

whisper.cpp 是 C++ 实现，不依赖 Python 的深度学习框架，编译一次就永久可用。

---

## 安装

### 1. 装依赖

```bash
pkg install git cmake make ffmpeg -y
```

### 2. 编译 whisper.cpp

```bash
cd ~
git clone --depth 1 https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make -j$(nproc)
```

编译完成后，可执行文件在 `build/bin/` 下：
- `whisper-cli` — 命令行转写工具（主要）
- `whisper-server` — HTTP 服务模式（可做 API）

### 3. 下载模型

```bash
# tiny (39MB) — 最快，适合短音频测试
bash models/download-ggml-model.sh tiny

# small (487MB) — 推荐，准确率和速度平衡
bash models/download-ggml-model.sh small

# medium (1.5GB) — 最准，但手机 CPU 转写较慢
bash models/download-ggml-model.sh medium
```

模型文件在 `~/whisper.cpp/models/ggml-*.bin`。

**模型选择建议：**
- 测试环境 → `tiny`
- 日常英文 → `small`
- 需要高准确率或中文 → `small` 或 `medium`
- 不建议在手机上用 `large` — 约3GB，转写速度很慢

---

## 使用

### 音频预处理

whisper.cpp 只接受 16kHz 单声道 WAV。任何格式先转：

```bash
# 从视频提取音频
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 -c:a pcm_s16le output.wav

# 从音频文件转换（mp3 → wav）
ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le output.wav
```

### 转写

```bash
cd ~/whisper.cpp

# 基础转写（自动检测语言）
./build/bin/whisper-cli \
  -m models/ggml-small.bin \
  -f ~/audio.wav \
  -l auto \
  --output-txt

# 指定语言
./build/bin/whisper-cli \
  -m models/ggml-small.bin \
  -f ~/audio.wav \
  -l zh \
  --output-txt

# 转写并保存多种格式
./build/bin/whisper-cli \
  -m models/ggml-small.bin \
  -f ~/audio.wav \
  -l auto \
  -t 4 \
  --output-txt \
  --output-srt \
  --output-file ~/transcript
```

### 输出格式

- `--output-txt` — 纯文本（一行一段）
- `--output-srt` — 字幕格式（带时间戳）
- `--output-vtt` — WebVTT（网页字幕）
- `--output-json` — JSON 格式（含词级时间戳）

---

## 性能（8核 ARM64, 12GB RAM）

| 模型 | 大小 | 2分钟音频 | 15分钟音频（估算） |
|------|------|-----------|-------------------|
| tiny | 39MB | ~20s | ~2.5分钟 |
| small | 487MB | ~84s | ~10-11分钟 |
| medium | 1.5GB | ~4分钟 | ~30分钟 |

全部跑在 CPU 上（默认 4 线程）。Android 上没有 GPU 加速。

---

## 进阶：定时录音 + 转写

结合 Termux 和 cron，让手机自动录音并转写：

```bash
# record-voice.sh
#!/data/data/com.termux/files/usr/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
# 录音 30 秒
termux-microphone-record -d 30 -f ~/recordings/$DATE.wav
# 转写
cd ~/whisper.cpp
./build/bin/whisper-cli \
  -m models/ggml-small.bin \
  -f ~/recordings/$DATE.wav \
  -l auto \
  --output-txt \
  --output-file ~/recordings/$DATE
```

需要 `termux-api` 包：
```bash
pkg install termux-api -y
```

---

## 常见问题

### "Could not open file"

音频文件不是 16kHz 单声道 WAV。用 ffmpeg 重新编码。

### "No speech detected"

音频太短或太安静。确保录音质量良好，或者用 `-l en` 指定语言而非 `auto`。

### 编译报错

```bash
# 清理重编译
make clean
make -j$(nproc)

# 确保 cmake 和 clang 最新
pkg upgrade cmake clang
```

### 内存不足

小模型（tiny/small）对 4GB RAM 手机友好。  
medium 建议 8GB+ RAM。  
不要在大模型上跑手机。

---

## 配合其他工具

whisper 输出可以接：
- **视频制作**（03-video-production）— 语音转字幕，加到短视频上
- **日记系统** — 口述日记后自动转录归档
- **AI 对话记录** — 把语音输入转文字喂给 AI

---

*有问题？提 issue 到 [termux-ai-toolkit](https://github.com/wjgong001/termux-ai-toolkit)。*
