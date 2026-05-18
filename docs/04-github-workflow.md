# 04 — GitHub 工作流：AI 的提交流程

> **目标：** 让 AI agent 能正确跟 GitHub 上的开源项目互动——提 issue、发 PR、参与讨论。
> **耗时：** 取决于项目复杂度

---

## 核心原则

1. **先读后写。** 看项目的 CONTRIBUTING.md、已有的 issue 讨论、PR 模板。
2. **加技术价值，不是噪音。** 每个 comment 和 PR 都要解决一个真实问题。
3. **知道什么时候退出。** 别人的解决方案更好？支持他们；维护者说 no？听。

---

## 开始之前

### 认证

```bash
# 设置 token
git config --global credential.helper store
echo "https://oauth2:YOUR_GITHUB_TOKEN@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials

# 验证
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/user" | python3 -c "import sys,json; print(json.load(sys.stdin).get('login','FAIL'))"
```

---

## 工作流分类

### 提 Bug

```markdown
## 描述
[一句话说明问题]

## 复现步骤
1. 用 XXX 版本
2. 调 YYY 函数
3. 传 ZZZ 参数
→ 报错

## 期望行为
[应该怎样]

## 实际行为
[现在怎样]

## 环境
- 包版本：
- Python：
- OS：
```

### 去 Issue 请求 Assign

有些项目（特别是 langchain）有自动流程：**没被 assign 的人提 PR 会被自动关。**

```markdown
Hi，我对这个 bug 有确定的修复方案。能 assign 给我吗？
```

**等待被 assign 后再提 PR。**

### 提 PR

```markdown
## 描述
[什么 bug / 什么功能]

## 根因
代码里哪里出的问题（文件和行号）。

## 修复
改了哪里，为什么这么改。

## 测试
[如何在本地验证 / 加新测试了吗]
```

---

## LangChain 特殊流程

LangChain 有自动关闭 PR 的机器人：**未关联 issue 或未 assign 的 PR 会被自动关。**

正确流程：

```mermaid
flowchart TD
    A[发现 bug] --> B[搜是不是已有 issue]
    B -->|有| C[评论请求 assign]
    B -->|没有| D[提 issue]
    C --> E[等维护者 assign]
    E -->|assign了| F[提 PR 关联 issue]
    E -->|没 assign| G[找下一个 bug]
    D --> H[等维护者回复]
    H --> E
    F --> I[等 review]
```

**重要教训：** 同一个 bug 不要反复投 PR。如果被自动关了，在 issue 下留言请求 assign。  
第三次还没动静，说明这个项目对未分配贡献者不友好——换下一个。

---

## CrewAI 工作流

CrewAI 的 issue 讨论更活跃。多人可能同时在对同一个问题提 PR。

- 如果别人的 PR 更精炼 → 关掉自己的 PR 并留言支持
- 如果自己的方案提供了不同视角 → 保持 PR 活跃并参与讨论

---

## GitHub 通知阅读

每个 wake cycle 检查：

```bash
# 检查通知
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/notifications?all=true&per_page=10" | \
  python3 -c "
import sys,json
for n in json.load(sys.stdin):
    r = n['repository']['full_name']
    t = n['subject']['title']
    reason = n['reason']
    print(f'  [{reason}] {r}: {t}')
"
```

按 `reason` 优先级：
1. `mention` — 被人直接 @（最高）
2. `comment` — 你参与过的 thread
3. `author` — 别人评论了你的 PR/issue
4. `review_requested` — 被要求 review
5. `subscribed` — 你在关注这个 repo（最低）

---

## 什么时候不要参与

- issue 有 300+ 评论（噪音太大）
- issue 已 assign 给别人
- 功能需求没有清晰规格
- 修复需要你没有的领域知识
- 同一个项目的同一个错误你发了 3 次 PR 都被机器关了

---

## 参考

- [02 — 语音转写](02-voice-to-text.md) — 可用 whisper 做字幕
- [03 — 视频制作](03-video-production.md) — PR 里带测试视频验证
