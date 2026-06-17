# /track v2 — Spec Architecture Redesign

> 状态:**已实施**(2026-06-16)—— SKILL.md 已重写为 v2(Step 1+2 合并落地:Current State 快照 + sessions/ file-per-session + compact/verify 子命令 + 向后兼容 legacy 单文件)。Session ID = 递增号+slug+撞车后缀,靠 `set -o noclobber` 原子创建(已测:同号撞车退避 001→001b→001c 零覆盖)。**plugin-ecosystem 未迁移**,按决定保留为 legacy 只读归档,v2 向后兼容读取。Step 3(迁移老 spec)留作按需。
> ——以下为原始设计稿(2026-06-14),保留作设计依据——
> 起因:`plugin-ecosystem` spec 跑了 35+ session 后涨到 **415KB / 2764 行**,暴露出当前 `/track` 的结构性瓶颈。本文是综合社区调研 + 实战经验后的改造蓝图。
> 已拍板:**session 文件 ID = 递增号 + slug + 撞车后缀**;落地节奏 = 先只出本文档。

---

## 1. 问题诊断:spec 自发演化成了 Event Sourcing,但塞进了一个文件

`/track` 的模板原本是一组有界命名章节(Overview / Architecture / Implementation Status / Progress / Key Files / Design Decisions / Issues / Lessons Learned),`/track update` 的铁律是 "NEVER remove content" + 章节内追加。

但在一个高压、多 agent 并发、跑了 35+ session 的超大 feature 上,agents **自发**演化出了一套截然不同的工作协议(skill 模板从没要求过):

- 顶部 newest-first 的 `## SESSION N (date) — 标题 — DoD徽章 — READ FIRST` 块,**纯 append 日志**
- DoD 状态编进标题(`✅ 实现+测试+ship+真机e2e全绿`)
- `[[memory-link]]` 连到持久记忆系统
- `READ 'SESSION 28' 块` 手搓内部交叉引用
- frontmatter `description` 被滥用成 **24KB 的恢复摘要**(设计上限 80 字符)
- 原模板的结构化章节被挤到末尾 18%,沦为遗迹 —— 真相全在 session 日志

### 量化(plugin-ecosystem,2026-06-14)

| 维度 | 值 |
|------|-----|
| spec.md | 2764 行 / 415KB |
| SESSION 块 | ~30 个,reverse-chronological |
| frontmatter description | 24,335 字符(上限 80) |
| 原模板章节位置 | 2248–2764 行(末尾遗迹) |
| 编号竞态留痕 | 重号 SESSION 21、22b/22c 与 23 交错 |

### 关键洞察:这就是 Event Sourcing

| Event Sourcing | spec 现状 | 病症 |
|---|---|---|
| event stream(append-only 真相源) | `## SESSION N` 块 | 塞进单文件 → 抢号 + 写冲突 + 无界 |
| snapshot / HEAD(派生、可重写、有界) | 滥用的 24KB frontmatter description | 放错地方 + 与原文双份膨胀 |
| 恢复 = snapshot + 其后事件 | 应:Current State + 最近 K 个 session | 被迫读 415KB 全史 |
| 读路径截断 ≠ 存储删除 | 老 session 该折叠归档 | 完全没有,只增不减 |

### 5 个痛点

1. **read 不可 scale** —— `/track read` "always print full spec" 已物理失效(超 256KB / 25k token 单调用上限)
2. **无界增长** —— 无 rollup / compaction,415KB 还会涨
3. **缺 fresh-agent orientation 区** —— 没有专门给冷启动 agent 的当前态单点 → 倒逼滥用 frontmatter
4. **并发写冲突 + 抢号** —— 单文件 + 自增编号,多 agent 必撞
5. **结构化模板 vs append 日志的张力** —— journaling 赢了(并发安全),但被塞进错误的容器

---

## 2. 社区调研综合(4 条独立线索)

> 完整调研见本文档第 7 节"调研来源"。四条线索收敛度极高。

### 可直接借鉴(成熟方案一致)

- **多文件按职责切**:Cline(6 文件)、spec-kit(6+)、Kiro(3)、BMAD(按 `##` sharding)**无一例外**。Kiro 明确点名"单一大 spec"为反模式。
- **覆写式 orientation 文件**:Cline `activeContext.md`(固定三段:Current Focus / Recent Changes / Open Questions),fresh agent 冷启动只读它。
- **结构化 vs append 物理分层**:RooFlow 已解 —— 易变当前态 = 结构化覆写文件;不可变历史 = append-only 带时间戳文件,**分文件**。`decisionLog.md`/`progress.md` 只 append 永不覆写,`activeContext.md` 可原地 `apply_diff`。
- **完成即归档(rollup 思想)**:OpenSpec `changes/` 完成后 delta 被吸收进主 `specs/`,过程文件整体移到 `archive/YYYY-MM-DD-<name>/`;主 spec 永远只反映当前真相。

### 社区没人解决、我们要自研的两块空白(做对就领先)

1. **Compaction / 有界增长**:Cline、RooFlow、spec-kit、Kiro **全部没有** rollup。要借 **MemGPT / LangChain 的递归增量摘要**:`new_snapshot = summarize(old_snapshot + 即将折叠的旧 session)`,**永不从全文重总结** —— 正根治 24KB 摘要反复重述而膨胀的病根。

2. **多 agent 并发抢号**:所有 worktree 编排器(Conductor / Claude Squad / vibe-kanban)的"看板"全是**只读聚合器,从不回写共享状态**;claude-task-master 的 `max(id)+1` 犯的是**和我们一模一样的抢号 bug**。根因:**任何"先看全局最大号再 +1"在并发下必撞**。最干净解 = **一 session 一文件,文件名即 ID(Maildir 模式)** —— 写目标天然不相交。

### 明确反模式(不抄)

- Cline"每任务开局读全部文件" —— 文件短时成立,415KB 场景照搬即放大痛点
- Windsurf 自动后台静默写隐藏记忆 —— 用户不可见、新旧假设混淆翻车。**我们的记忆必须人可读、可 diff、写入显式可见**
- spec-kit 的 constitution 9-articles + phase gates —— 重流程,适合从零立项,不适合实时追踪已有大 feature
- frontmatter 当恢复摘要 —— 我们的现状,所有方案都用独立 activeContext 文件

---

## 3. 目标架构

```
~/.agents/.features/<feature>/
├── spec.md                    # ① 稳定头 + ② Current State 快照(覆写,有界 ≤~6KB)+ 自动 session TOC
├── sessions/
│   ├── 036-mcp-transport.md   # ③ 一 session 一文件,append-only,写完即冻结
│   ├── 035-paid-plugin.md     #    文件名 = <递增号>-<slug>,各 agent 各写各的
│   └── ...
└── archive.md                 # ④ 老 session 折叠成一行/归档,读路径默认跳过(不删,可审计)
```

设计原则:**易变的当前态用结构化覆写(spec.md 的 Current State),不可变的历史用 append-only 冻结文件(sessions/),老历史折叠归档(archive.md)。三区严格分层。**

### 3.1 `spec.md` 结构

```markdown
---
group: darkmatter
branch: plugin-ecosystem
status: in-progress
description: "插件生态:catalog/outsight/沙箱同步/MCP-OAuth(≤80 字符)"   # ← 收回一行
created: 2026-06-01
updated: 2026-06-14
repos:
  darkmatter: { worktree: /path/... }
  ...
---
# Plugin Ecosystem — Spec

## Current State            ← SNAPSHOT / HEAD(派生、可整块覆写、有界)
### Decisions              # 按 key 去重,同 key 只留最新结论
- `oauth-keying`: full-URL(去 query/fragment),非 origin。理由 RFC8707 多租户。
- `host-kind`: 作者 interface.hostKind 显式声明 > stdio 派生 > hosted 默认。
- ...
### Open Risks & TODOs      # ⚠️ 逐字保留,永不压缩
- [ ] MR !2910 + !564 待合主干
- [ ] S35 Phase 2:跨仓让作者声明 MCP transport
- ...
### Key Files               # 按 repo|file 去重覆盖
| Repo | File | Purpose |
### Verify Status           # 当前 pass/fail 命令 + 部署 revision
- darkmatter HEAD 658ad5b36 / argo kimi Synced+Healthy
### Active Sessions         # 指向进行中/最近的 session
- → sessions/036-mcp-transport.md(S35 Phase 1 done, Phase 2 TODO)

## Sessions (TOC)            ← 自动生成的目录,newest-first
| # | Slug | Date | Status | 一句话 |
|---|------|------|--------|--------|
| 036 | mcp-transport | 06-14 | ✅code+test+ship+e2e | 百度 SSE transport override |
| 035 | paid-plugin   | 06-13 | ✅ | 付费插件额度提示文案 |
```

**Current State 是派生快照** —— 理论上可由全部 session 重建(像 snapshot 可从 eventstream 重建),所以"可整块覆写"不算丢数据。这是它区别于 append 区的根本属性。

### 3.2 `sessions/<NNN>-<slug>.md` 结构(固化 agents 自发的 schema)

```markdown
# SESSION 036 — MCP transport(SSE vs streamable)— ✅ code+test+ship+e2e

**date**: 2026-06-14 · **agent**: <可选,并发时填> · **status**: Phase 1 done / Phase 2 TODO

> 症结:百度网盘授权 OK 但运行时连不上,根因 = 物化 MCPUserSetting 硬编码 HTTP,百度是 SSE。

## 设计结论(用户拍板)
...
## 实现(repo HEAD / commit / 文件锚点)
...
## Ship + 真机 e2e
...
## 待办 / 教训
- [[reference_mcp_transport_per_host_override]]
```

写完即冻结(append-only,不再覆写)。需要推翻前述结论时,**写新 session 说明,不改旧文件**(event sourcing 的 compensating event)。

### 3.3 Session ID 规则(已拍板:递增号 + slug + 撞车后缀)

文件名格式:`<NNN>-<slug>.md`,如 `036-mcp-transport.md`。

**为什么递增号在 file-per-session 下是安全的**(关键):
- 单文件 append 时,"看最大号 +1" 是 race,因为两个 agent 写进**同一个文件**互相覆盖、且无法检测冲突。
- file-per-session 下,号只决定**文件名**。写入用 `O_CREAT|O_EXCL`(create-if-not-exists)语义 —— 若 `036-*.md` 已存在,**写入原子失败**,第二个 agent 据此退避。
- **撞车后缀规则**:目标文件名已存在 → 依次尝试 `036b-<slug>.md` → `036c-...`(或并发标识 `036-<agent-short>-<slug>.md`)。两份都保留,**零数据丢失、零覆盖**。
- 因此:日常串行 → 干净递增;偶发并发 → 自动退避成 `036b`,正是实战中已出现的 `22b/22c` 的形式化。

实施要点:
- `/track update` 写 session 前:`ls sessions/` 取当前最大号 → +1 → 用 exclusive-create 落盘 → 冲突则加后缀重试。
- slug:从 session 标题 kebab-case 截断(≤30 字符)。
- 排序:文件名字典序 ≈ 时序(`036` < `036b` < `037`),TOC 据此生成。

---

## 4. `/track` 子命令变更

| 子命令 | 现状 | v2 |
|--------|------|-----|
| `read` | always print full spec(已失效) | 默认回 **frontmatter + Current State + Sessions TOC**;`read --session <N>` 读单个 session 文件;`read --full` 全量(分页);`read --archive` 看归档 |
| `update` | 改结构化章节,NEVER remove | **写/追加自己的 session 文件**(exclusive-create + 撞车后缀)+ **增量覆写 Current State**(old + 本 session → new,Open Risks 豁免);末尾检查是否触发 compact |
| `new` | 建 spec.md(单文件) | 建 `<feature>/` 目录骨架(spec.md + sessions/ + archive.md) |
| `compact` | **(新增)** | 折叠最旧 session:递归增量摘要进 Current State + 压成一行进 archive.md(详见 §5) |
| `verify` | **(新增,可选)** | 拿 Current State 的声称项去代码搜证据,标"声称完成但无代码 / 代码已做但没记"(借 OpenSpec `/opsx:verify`,根治 Implementation Status 脱节) |
| `list` / `switch` / `done` / `archive` / `reindex` | 单文件假设 | 适配多文件;`.index.json` 的 description 取 spec.md 的 Current State 首行,不再取 frontmatter 长文 |

---

## 5. Compaction 规则(markdown-only,无需向量库)

新增 `/track compact`(或并入 `/track update` 尾部检查)。把 MemGPT / LangChain / event-sourcing 思想退化成纯 markdown 可执行规则。

**触发条件(token 阈值 + 计数兜底):**
- `sessions/` 中非归档 session > 8 个,或活跃 session 累计 > ~12KB → 触发。

**算法:**
1. **保留最近 8 个 session 原文**(滑动窗口,K=8 适配长 feature)。
2. **更老的 session 增量折叠**:取「现有 Current State + 即将折叠的旧 session」,refine 出新 Current State **覆盖**旧块(`predict_new_summary(pruned, old_summary)`,**绝不从零重写全史**):
   - 决策/约束按 **key 去重**写进 `### Decisions`(同 key 后写覆盖)
   - 未解 TODO / 踩坑 **逐字搬进** `### Open Risks & TODOs`(豁免压缩)
   - 改动文件 merge 进 `### Key Files`(按 repo|file 去重)
3. **被折叠的 session 不删** → 每个压成一行 `- SESSION N (date): <12字结论>` 移入 `archive.md`(或 `sessions/archive/`)。读路径默认跳过,审计仍可查。

**compaction 保留 / 压缩清单**(跨 5 方案一致结论):

| 逐字保留(豁免压缩) | 可压成一行(lossy) |
|---|---|
| 架构 / 设计决策 **+ 理由** | 工具/命令完整输出 → 只留结论 |
| 未解 bug / open risk / 踩坑 / 已知陷阱 ⚠️ | 中间推理 / 试错链 → "试过 A/B 失败,选 C" |
| 约束 / 不变量 / "必须做 X、绝不做 Y" | 例行 git log/diff 罗列 → "本 session 改了 X、Y" |
| 待办 / 当前进度 | 冗余、已被取代的旧讨论 |
| 改动文件 + 关键代码片段 | |
| 错误 + 修复方式(结论行) | |
| 用户原始意图 | |

**铁律:**先 maximize recall(别漏)再提 precision(删冗余);`Open Risks` 与 `Lessons` 两节**永不压缩**。Anthropic 官方逐字警告:过度压缩会丢"当时看不出、后来才致命"的上下文。

**去重不变量:**Current State(抽取结论)与 session(原文)**不互相复述**;Current State 内按 key 单值,写新结论 = 覆盖同 key 旧行,不追加第二行。这直接治 24KB"摘要+原文"双份膨胀。

---

## 6. 实施节奏(风险递增,每步可独立停)

> 已选:**先只出本设计文档(本文)**。以下为后续可选执行阶段,留作 crunch 后参考。

- **Step 1(零风险,原地)**:修 `read` 的 scale bug + 给现有 415KB spec **原地加 Current State 块**(不迁移)。立刻让 fresh agent 能低成本恢复。
- **Step 2(低风险,只影响新 feature)**:改 skill 模板 + 子命令支持 file-per-session + compact/verify。新 feature 自动用新结构,老 spec 不动。
- **Step 3(一次性迁移)**:把 plugin-ecosystem 的 ~30 个 SESSION 块机械拆进 `sessions/`,从最新 session 构建 Current State,老的进 archive.md。**可逆**(原 spec.md 备份),但动正在用的 spec,留到 crunch 后。

---

## 7. 调研来源(2026-06-14,WebSearch+WebFetch 核实一手源)

**Memory Bank 类**
- Cline Memory Bank — docs.cline.bot/best-practices/memory-bank;github.com/cline/prompts `.clinerules/memory-bank.md`(6 文件依赖层级,无 compaction)
- Roo Code / RooFlow — github.com/GreatScottyMac/RooFlow(per-file 写策略:decisionLog/progress 只 append+时间戳,activeContext 可 apply_diff;状态前缀协议;UMB 命令)
- Indexed Memory Routing — MEMORY.md 索引 + memory/<topic>.md 按需读;memory.md ≤200 行约束
- Claude Code 适配 — github.com/hudrazine/claude-code-memory-bank;PreCompact 钩子"压缩前快照"

**Spec-driven 类**
- GitHub spec-kit — github/spec-kit(spec/plan/tasks/research/data-model/contracts 多文件 + constitution + phase gates)
- AWS Kiro — kiro.dev/docs/specs(requirements/design/tasks 三件套 + EARS + Sync Files;明确反对单一大 spec)
- OpenSpec — github.com/Fission-AI/OpenSpec(specs/=当前真相 vs changes/=进行中,完成即 delta 吸收 + archive/YYYY-MM-DD;`/opsx:verify` 对账 + `/opsx:continue` orientation)
- Harper Reed LLM codegen — harper.blog 2025/02/16(spec→prompt_plan→todo,最轻量但无 truth/archive)

**任务编排 / 多 agent / 并发 ID**
- claude-task-master — github.com/eyaltoledano/claude-task-master(tasks.json + tag 隔离,**max(id)+1 抢号 bug**)
- BMAD-METHOD — github.com/bmad-code-org/BMAD-METHOD(**doc sharding 按 `##` 切 + index.md 导航 + devLoadAlwaysFiles**;一 story 一文件 + per-section owner/editors;story 自包含 Dev Notes)
- worktree 编排器(Conductor / Claude Squad / Nimbalyst / vibe-kanban / uzi)— 共识:**看板皆只读聚合器,从不回写共享状态;无原子 task-claim 锁**
- ID 先例 — ULID(github.com/ulid/spec)、UUIDv7(RFC 9562)、KSUID、Snowflake、**Maildir(cr.yp.to/proto/maildir.html,一文件一 ID 无锁)**、Kafka log compaction

**记忆架构 / compaction**
- MemGPT / Letta — arxiv 2310.08560;docs.letta.com memory-blocks(70% 软警告→100% 硬 flush;**递归增量摘要**;记忆块 limit;archival 默认不在场按需召回;sleep-time 异步整合)
- mem0 — arxiv 2504.19413;github.com/mem0ai/mem0 prompts.py(extract→update 的 ADD/UPDATE/DELETE/NOOP;先检索相似再合并去重;v3 反转为 ADD-only + 读时去重)
- Anthropic / Claude Code — code.claude.com/docs context-window;anthropic.com/engineering/effective-context-engineering(auto-compact 保留清单:意图/决策/文件/未解bug/待办,丢工具输出/中间推理;"压缩前先落盘";警告过度压缩)
- Cursor self-summarization — cursor.com/blog/self-summarization(RL 训练自总结,阈值暂停先总结,~1000 token + 历史当可检索文件)
- LangChain/LangGraph rolling summary — ConversationSummaryBufferMemory(token 阈值 pop 最旧 + 增量 refine 单条 moving summary + 保留最近窗口)
- Event sourcing — martinfowler.com/eaaDev/EventSourcing;learn.microsoft.com Event Sourcing pattern;Kafka log compaction(snapshot 派生 + 读路径截断 ≠ 存储删除 + 按 key 去重)
