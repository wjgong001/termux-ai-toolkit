# 08 — 命令行浏览器：当 API 不够用的时候

> **很多网站不提供 API，或者 API 需要认证。但作为 AI agent，你仍然可以"看"到它们的内容。**
> 命令行浏览器（links、lynx、w3m）能渲染 HTML，输出纯文本。
> 不需要无头浏览器，不需要 GPU，不需要 JavaScript 引擎。

## 什么时候需要这个

- 网站没有公开 API（今日热榜、Reddit、HackerNews 的 HTML 版）
- API 需要 OAuth 认证，你没有浏览器环境去完成登录流程
- 页面内容由 JS 动态渲染，requests 拿不到（SPA 站点）
- 你想"看"一个页面的大致内容，而不是从 JSON 碎片中拼凑

## 安装

```bash
# 全部装上，选一个用
pkg install links lynx w3m elinks
```

links 最推荐——输出格式最干净，表格和列表渲染最好。

## 基础用法

### links（推荐）

```bash
# 显示为纯文本
links -dump "https://tophub.today"

# 可交互浏览（有键盘导航）
links "https://tophub.today"

# 输出到文件
links -dump "https://tophub.today" > today.txt

# 不显示链接URL（更干净）
links -dump -no-numbering -no-references "https://tophub.today"
```

### lynx

```bash
# 纯文本输出
lynx -dump -nolist "https://ai-brief.liziran.com/zh/"
```

### w3m

```bash
# 纯文本输出
w3m -dump "https://tophub.today"

# 遇到 SSL 错误的补救
w3m -insecure -dump "https://example.com"
```

## 用 links 批量采集热榜

links 非常适合抓取**聚合类站点**——它们的特点是多来源、多板块、纯文本结构清晰。

### 采集今日热榜 (tophub.today)

```bash
links -dump "https://tophub.today" 2>&1 | grep -A 10 "微博" | head -12
```

输出示例：
```
微博 ‧ 热搜榜
1. 留神峪煤矿事故82人遇难 25万
2. 不许再霸凌自己了 18万
3. 中国硬核实力又刷屏了 15万
```

### 在 Python 中调用

```python
import subprocess
import re

def fetch_hotlist(url="https://tophub.today"):
    """用 links 抓取热榜，返回结构化数据"""
    result = subprocess.run(
        ["links", "-dump", url],
        capture_output=True, text=True, timeout=30
    )
    text = result.stdout
    
    # 提取各板块
    sections = {}
    current_section = None
    for line in text.split('\n'):
        # 匹配板块标题行
        m = re.match(r'\s{2,}(.+热搜榜|.+热榜|.+热点|.+日榜|.+趋势).*', line)
        if m:
            current_section = m.group(1).strip()
            sections[current_section] = []
        elif current_section and re.match(r'\s+\d+\.', line):
            sections[current_section].append(line.strip())
    
    return sections

# 使用
hotlist = fetch_hotlist()
for section, items in hotlist.items():
    print(f"\n{section}:" if not items else "")
```

### 特别注意

1. **SSL 问题**：部分站点（如 buzzing.cc）SSL 证书不对。试试 w3m 的 `-insecure` 或用 curl 先下再传 pipe。
2. **JavaScript 站点**：links 不执行 JS，SPA（单页应用）抓不到内容。NewsNow、AttentionVC 是 SPA，links 看不到东西。
3. **编码**：中文站点默认 UTF-8，links 支持良好。如果乱码，检查终端 locale。
4. **网络超时**：用 `timeout` 命令限制执行时间，避免挂住：
   ```bash
   timeout 15 links -dump "https://example.com"
   ```
5. **不要高频请求**：links 发的是普通 HTTP 请求，频率太高会被限流。两次抓取间隔至少 30 秒。

## 哪些站能用，哪些不行

### ✅ 能用的（links/w3m 渲染良好）
- **今日热榜** (tophub.today) — 微博/知乎/微信/B站/百度热搜，完整
- **AI论文简报** (ai-brief.liziran.com) — 每日论文摘要，完整
- **GitHub** — 仓库页面、issues、trending
- **Wikipedia** — 纯文本版很正常
- **HackerNews** (news.ycombinator.com) — 经典文本站
- 任何服务端渲染的新闻站、博客、文档站

### ❌ 不行的（SPA/JS渲染）
- **NewsNow** (newsnow.busiyi.world) — Next.js SPA，内容是空的
- **AttentionVC** (attentionvc.ai) — Next.js SPA

### ⚠️ 视情况
- **Buzzing** (buzzing.cc) — SSL 问题，需要 `w3m -insecure` 尝试。部分路由可能有服务端渲染

## links 的局限

1. **只输出文本**：表格布局可能错位，图片不可见
2. **超链接丢失**：默认模式会显示链接 URL，用 `-no-numbering` 可隐藏
3. **SSL/TLS**：不支持最新 TLS 扩展，部分 HTTPS 站连不上
4. **不支持 cookie 管理**：无法保持登录态
5. **渲染速度**：大页面（1000+行）需要 3-5 秒

## links 的优势

1. **零依赖**：一个二进制文件就能跑，不需要 Python、Node、浏览器引擎
2. **极快**：比 Curl_cffi 快，比 requests+lxml 快
3. **输出干净**：自动去掉 HTML 标签、清理空白、对齐表格——直接可以给 AI 读
4. **跨平台**：任何 Linux 环境都能装，Termux 上 pkg install 几秒就好
5. **开源**：GPL 许可证，可随意使用

## 什么时候选 links 而不是 requests

| 场景 | 推荐方案 |
|------|---------|
| 网站有 JSON API | requests |
| 网站是服务器端渲染的 HTML | links 或 requests+lxml |
| 网站需要模拟浏览器指纹 | curl_cffi |
| 网站有 Cloudflare 防护 | curl_cffi (impersonate模式) |
| **想看人类看到的页面布局** | **links** |
| 需要交互式浏览（翻页、填表单） | links (交互模式) |
| 只需要快速看一眼内容 | links -dump |
