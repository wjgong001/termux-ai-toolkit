# 03 — 手机短视频生产：Edge TTS + ffmpeg

> **目标：** 在 Android Termux 上用文案直接生成竖屏短视频（旁白 + 图片轮播 + 字幕）。
> **耗时：** 从文案到成片约 5-10 分钟
> **先决条件：** 已装 Termux、ffmpeg、Python（参考 01-bootstrap）

---

## 核心方案

```
文案 → Edge TTS 语音 → ffprobe 逐句测时长 → 
逐句生成视频片段（图片+字幕+语音）→ concat 合并 → 输出
```

手机上不要用 Pillow/OpenCV 逐帧渲染，不要用 p5.js 做动画。  
**全部用 ffmpeg 滤镜完成。** 手机 CPU 扛得住。

---

## 第一步：装依赖

```bash
pip install edge-tts
pkg install ffmpeg -y
```

Edge TTS 是微软的文字转语音，中文语音（晓晓）很自然。  
**不要用 gTTS** — 音质像机器人。只有在 Edge TTS 连不上时才降级。

---

## 第二步：预备图片

图片放到 `~/storage/downloads/video素材/`（手机 Download 目录）。

每张图会自动裁成竖屏 1080×1920。两种裁法：

```bash
# 模式A：等比例缩放后黑边补全（适合有人物的照片）
ffmpeg -i input.jpg -vf \
  "scale=1080:1920:force_original_aspect_ratio=1,pad=1080:1920:(ow-iw)/2:(oh-ih)/2" \
  -frames:v 1 output.jpg

# 模式B：裁切全屏铺满（适合天空/风景）
ffmpeg -i input.jpg -vf \
  "scale=1080:1920:force_original_aspect_ratio=2,crop=1080:1920" \
  -frames:v 1 output.jpg
```

---

## 第三步：写文案，生成语音

文案按句拆分，每句一条语音。**串行生成，不要用 async。**

```bash
texts=("第一句话" "第二句话" "第三句话")

cd ~/demoscene/tmp
for i in "${!texts[@]}"; do
  n=$(printf "seg_%02d" $i)
  edge-tts --voice zh-CN-XiaoxiaoNeural \
    --text "${texts[$i]}" \
    --write-media "${n}.mp3"
done
```

**关键：** 逐句测每段时长（不同句子语气不同，时长差很大）：

```bash
for f in seg_*.mp3; do
  dur=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$f")
  echo "$f: $dur 秒"
done
```

---

## 第四步：逐句合成视频片段

核心逻辑：每句语音的时长决定该段视频的帧数。

```python
for i in range(len(texts)):
    n_frames = round(durations[i] * 25)  # 25fps
    actual_dur = n_frames / 25
    
    vf = "多个 drawtext filter，每行一个字幕层"
    
    ffmpeg -loop 1 -i background.jpg \
      -vf "$vf" \
      -t $actual_dur \
      -frames:v $n_frames \
      -c:v libx264 -pix_fmt yuv420p \
      seg_${i}.mp4
```

---

## 字幕：关键避坑

手机上做字幕最容易翻车的地方：

### ✅ 正确做法：多个 drawtext filter

每个字幕行用一个独立的 drawtext 层：

```bash
filter="drawtext=text='第一行':x=(w-text_w)/2:y=800:fontsize=60,
         drawtext=text='第二行':x=(w-text_w)/2:y=890:fontsize=60"
```

### ❌ 不要做的事

| 做法 | 结果 |
|------|------|
| `textfile=` 传多行文本 | 换行符变方框字符 |
| `\\N` 做换行 | 显示为字母 N |
| `text='I\'m'`（包含单引号） | 截断 filter，报错 |
| `drawbox` 加背景遮罩 | 挡住图片 |

### 字幕规格

- 字号：60-68px（中文），52-58px（英文）
- 白色字 + 黑色描边：`fontcolor=white:bordercolor=black:borderw=5`
- 每行最多 14-16 个汉字（英文 22-26 字符）
- 行间距 90px
- 字体路径：`/system/fonts/NotoSansCJK-Regular.ttc`

---

## 第五步：合并所有片段

```bash
# 写 concat 列表
for f in seg_*.mp4; do echo "file '$PWD/$f'" >> concat.txt; done

# 合并视频轨
ffmpeg -f concat -safe 0 -i concat.txt -c copy vid.mp4

# 合并音频轨
for f in seg_*.mp3; do echo "file '$PWD/$f'" >> concat_a.txt; done
ffmpeg -f concat -safe 0 -i concat_a.txt -c copy all_audio.mp3

# 视频+音频合体
ffmpeg -i vid.mp4 -i all_audio.mp3 \
  -c:v copy -c:a aac -shortest \
  ~/storage/downloads/final.mp4
```

---

## 完整工作流（从零到片）

以下是一个一步到位的 Python 脚本骨架：

```python
import subprocess, os, json

HOME = os.path.expanduser("~")
TMP = os.path.join(HOME, "demoscene/tmp")
os.makedirs(TMP, exist_ok=True)

# 1. 文案（按句拆分）
texts = ["第一句...", "第二句...", ...]

# 2. 每句生成 TTS（串行）
for i, t in enumerate(texts):
    out = os.path.join(TMP, f"seg_{i:02d}.mp3")
    subprocess.run(["edge-tts", "--voice", "zh-CN-XiaoxiaoNeural",
                    "--text", t, "--write-media", out], check=True)

# 3. 测量每段时长
durations = []
for i in range(len(texts)):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
                        "format=duration", "-of", "json",
                        os.path.join(TMP, f"seg_{i:02d}.mp3")],
                       capture_output=True, text=True)
    d = json.loads(r.stdout)["format"]["duration"]
    durations.append(float(d))

# 4. 逐句造视频片段
fps = 25
font = "/system/fonts/NotoSansCJK-Regular.ttc"
bg = os.path.join(HOME, "storage/downloads/video素材/bg.jpg")

for i, t in enumerate(texts):
    n_frames = round(durations[i] * fps)
    seg_out = os.path.join(TMP, f"seg_{i:02d}.mp4")
    
    vf = (f"drawtext=text='{t}':fontfile={font}:fontcolor=white:"
          f"bordercolor=black:borderw=5:fontsize=60:"
          f"x=(w-text_w)/2:y=(h-text_h)/2")
    
    subprocess.run(["ffmpeg", "-y", "-loop", "1", "-i", bg,
                    "-vf", vf, "-t", str(n_frames/fps),
                    "-frames:v", str(n_frames),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-an", seg_out], check=True)

# 5. 合并
# (见上一步的 concat 流程)
print(f"✅ Done: {os.path.join(HOME, 'storage/downloads/final.mp4')}")
```

**注意：** 如果文案中有英文单引号（`I'm`、`can't`），用 `textfile=` 传入临时文件代替 `text='...'` 写法。

---

## 选做：加 BGM

BGM 放到 `~/storage/downloads/BGM励志/`（手机目录）。

```bash
ffmpeg -i final.mp4 -i bgm.mp3 \
  -filter_complex "[1]volume=0.15[bg];[0:a][bg]amix=inputs=2:duration=longest" \
  -c:v copy -map 0:v -map "[a]" -shortest output_bgm.mp4
```

`duration=longest` 必须用，不要用 `first`（可能截断）。

---

## 性能参考

| 步骤 | 耗时 |
|------|------|
| 10 句 × Edge TTS | ~30 秒 |
| 10 段 × ffmpeg 渲染 | ~2 分钟 |
| concat 合并 | ~5 秒 |
| **总计（10句文案）** | **~3-5 分钟** |

全程在手机 CPU 上跑。如果网络不稳定，Edge TTS 可能超时——降级到 gTTS。

---

## 常见问题

**Q: 字幕变方框**  
A: 字体路径不对。Android 系统字体在 `/system/fonts/NotoSansCJK-Regular.ttc`。

**Q: 视频太短被截断**  
A: 音频轨道比视频长或短。用 `-shortest` 参数统一以短的为准。

**Q: 生成了空音频文件**  
A: Edge TTS 网络超时。重新跑那条语句，或者换 gTTS。

**Q: drawtext 渲染卡死**  
A: 如果 20+ 条 drawtext filter 堆叠，超过手机处理能力。分段渲染后再 concat。

---

*有问题？提 issue 到 [termux-ai-toolkit](https://github.com/wjgong001/termux-ai-toolkit)。*
