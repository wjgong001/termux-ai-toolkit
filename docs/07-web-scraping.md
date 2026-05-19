# 07 — Termux 网页抓取与数据采集

> **端侧 AI agent 需要从网页获取信息。** 不需要浏览器引擎，不需要无头浏览器。  
> requests + lxml + 智能策略，在手机上就能抓。

## 安装

```bash
# requests 通常已预装
pkg install python-lxml
```

这就是全部依赖。两个包都提供预编译的 wheel，手机上 10 秒装完。

## 基础：抓取并解析

```python
import requests
from lxml import html

# 抓取
r = requests.get('https://example.com', timeout=15)
# 可加 headers 避免被 ban
# headers = {'User-Agent': 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36'}
# r = requests.get('https://example.com', headers=headers, timeout=15)

# 解析
tree = html.fromstring(r.text)

# CSS 选择器（最常用）
title = tree.cssselect('h1')[0].text_content()

# XPath（更精确）
items = tree.xpath('//div[@class="post"]/h2/text()')

# 找链接
links = tree.cssselect('a[href]')
urls = [a.get('href') for a in links]
```

## 实用技巧

### 自动编码处理

Termux 的 Python 会正确检测编码。如果你遇到乱码：

```python
# 手动指定编码
r.encoding = r.apparent_encoding
# 或强制 UTF-8
# r.encoding = 'utf-8'
```

### 处理动态内容

如果页面内容由 JavaScript 渲染，requests 拿不到。但在手机上也有办法：

```python
# 1. 检查页面是否有 <script> 埋了 json 数据
import json
import re

scripts = tree.cssselect('script')
for s in scripts:
    text = s.text_content()
    # 很多站点把数据塞在 window.__INITIAL_STATE__ 这类变量里
    match = re.search(r'window\.__INITIAL_STATE__\s*=\s*({.*?});', text, re.DOTALL)
    if match:
        data = json.loads(match.group(1))
        # 直接用 data
```

### 智能重试与反爬

```python
import time
from functools import wraps

def smart_retry(max_retries=3, base_delay=2):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for i in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except (requests.exceptions.ConnectionError,
                        requests.exceptions.Timeout) as e:
                    if i == max_retries - 1:
                        raise
                    delay = base_delay * (2 ** i)  # 指数退避
                    print(f'请求失败 ({i+1}/{max_retries}), {delay}s 后重试...')
                    time.sleep(delay)
        return wrapper
    return decorator

@smart_retry()
def fetch_page(url):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 15) '
                       'AppleWebKit/537.36 Chrome/120.0.0.0'
    }
    r = requests.get(url, headers=headers, timeout=15)
    r.raise_for_status()
    return r.text
```

### 完整示例：抓取 GitHub issues

```python
import requests
from lxml import html
import json

def fetch_github_issues(repo: str, state: str = 'open', limit: int = 10):
    """抓取 GitHub issue 列表"""
    url = f'https://github.com/{repo}/issues'
    params = {'q': f'is:issue is:{state} label:good-first-issue'}
    
    r = requests.get(url, params=params, timeout=15)
    tree = html.fromstring(r.text)
    
    issues = []
    for item in tree.cssselect('[data-testid="issue-row"]')[:limit]:
        title_el = item.cssselect('[data-hovercard-type="issue"]')
        if title_el:
            title = title_el[0].text_content().strip()
            link = 'https://github.com' + title_el[0].get('href', '')
            issues.append({'title': title, 'url': link})
    
    return issues

# 使用
issues = fetch_github_issues('wjgong001/termux-ai-toolkit')
for i in issues:
    print(f"{i['title']}: {i['url']}")
```

## 注意事项

1. **不要高频请求** — 手机上网络不稳定，发太多请求会被限流。两次请求之间至少间隔 1 秒。
2. **不要抓需要登录的页面** — Termux 没有浏览器 cookie 存储，登录态管理复杂。除非你用 session 手动维护 cookie。
3. **大页面解析慢** — 超过 1MB 的 HTML 页面，lxml 解析可能需要 5-10 秒。先检查 `r.headers.get('content-length')`。
4. **SSL 问题** — 某些旧 Android 版本证书过期。解决方法：

```bash
# 更新 ca-certificates
pkg upgrade ca-certificates

# 或跳过证书验证（不推荐，仅调试用）
# requests.get(url, verify=False, timeout=15)
```

## 进阶：关于 Scrapling

[Scrapling](https://github.com/D4Vinci/Scrapling) 是一个更强大的 Python 抓取库，提供：
- 智能元素匹配（自动找"标题""正文"等常见元素）
- 内置 curl_cffi 引擎（指纹模拟、反 bot 检测）
- 动态页面支持（Camoufox/Playwright）

**但在 Termux 上，它依赖的 orjson 需要编译（手机上编译会超时），curl_cffi 和 Camoufox 需要 cffi 和浏览器引擎。** 所以 Scrapling 更适合桌面/云服务器环境使用。

如果你在云服务器或 WSL 上跑采集任务，推荐直接用 Scrapling：

```bash
pip install scrapling
```

```python
from scrapling import Fetcher
f = Fetcher()
page = f.get('https://example.com')
# 自动处理反爬、智能元素匹配
title = page.css('h1').text
```

在 Termux 上，requests + lxml 覆盖 90% 的场景。剩下的 10%（动态 JS 渲染、高级反爬绕过），等手机的算力和库生态成熟了再说。
