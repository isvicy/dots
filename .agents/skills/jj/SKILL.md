---
name: jj
description: >-
  Jujutsu（jj）VCS 的最佳实践与踩坑指南：rebase / squash / absorb / 书签 /
  divergent / 合并冲突 / 栈式 MR / 备份回滚。在 jj workspace 里做历史改写、
  解冲突、fold 修正、推送、栈管理，或遇到 divergent、conflict、书签 ??、
  命令挂死（起编辑器）时必读。 jj 行为不符合预期时：先查官方 docs/FAQ 与
  本 skill，不要闭门造车。
metadata:
  category: vcs
---

# jj（Jujutsu）最佳实践

面向 agent 的 jj 操作纪律与踩坑清单。规则来源：`docs.jj-vcs.dev` 官方文档
与真实事故（日期标注）。遇到本 skill 未覆盖的非预期行为：**先查官方
[FAQ](https://docs.jj-vcs.dev/latest/FAQ/) 与
[guides](https://docs.jj-vcs.dev/latest/guides/)，再动手**；解决后按
「现象 → 根因 → 正确姿势 → 出处/日期」追加到「踩坑清单」。

## 心智模型（30 秒版）

- **working copy 就是一个 commit（`@`）**：几乎每条 jj 命令都会先把工作副本
  快照进 `@`。做临时改动前先想清楚它会落到哪个 change。
- **`@` 只指当前 workspace 的 working copy**：多 workspace 各有独立的
  `<name>@`；revset `working_copies()` 是所有 workspace 的 @ 的集合。
- **change-id ≠ commit-id**：重写（rebase/amend/squash）保留 change-id、
  产生新 commit-id。书签绑的是 **change-id**，会跟随重写漂移。
- **visible vs hidden**：被重写的旧版本默认 hidden，但 `jj new <hidden>`、
  给它加书签、或 fetch 带回它的后代，都会让它**重新可见**——这是
  divergent 与「垃圾线」的来源。对照历史状态（oracle）一律用 **commit id**，
  不用书签、不用 change-id。
- **书签 `??`** = 书签冲突（本地与 origin 位置不可调和），用
  `jj bookmark set <name> -r <commit>` 定到正确位置后 push。
- **`jj diff` / `jj st` 的方向是 `@- → @`**（本 change 自己的增量），不是
  「`@` → 未提交改动」；看未快照改动用 `jj diff --from @`。

## 铁律（agent 执行纪律）

1. **非交互**：所有命令带 `-m`；`jj squash` 恒加
   `--use-destination-message`（不带会起编辑器合并描述，无 TTY 必挂死）。
   不用 `jj split -i` / `jj squash -i`（天然交互）。发现命令秒级无响应，
   查 `pgrep -fl 'jjdescription'` 杀掉后带 flag 重跑。
2. **解冲突只用**：`jj new <冲突段>` → 编辑文件消掉 `<<<<<<<` 标记 →
   `jj squash --use-destination-message`（官方 FAQ 推荐姿势）。**不要
   `jj edit <带冲突的段>`**——FAQ 明确警告会直接改坏冲突标注而不自知。
   自底向上逐段解（`roots(trunk()..<tip> & conflicts())` 找最底的）。
3. **fold 修正到祖先段，先 `jj absorb --from <change>`**：按「最后触碰这些
   行的最近可变祖先」自动分发 hunk，歧义时保守留在源 change（事后
   `jj op show -p` 审一眼）。**整段合并**（两个 change 合成一个）才用
   `jj squash --from <src> --into <dst> --use-destination-message`。
4. **每轮历史手术后三查**：
   - `jj log | grep -ci divergent` 应为 0，非 0 就 abandon 无主版本
     （`change_id(X) ~ bookmarks()` 列出来逐个确认后 `jj abandon <commit>`）；
   - `jj log -r 'trunk()..<tip> & conflicts()'` 应为空；
   - 验证不只跑构建：构建**不覆盖** TS/MD/yaml——内容断言用 grep（关键行
     在不在、禁词零残留、文件非空）。
5. **脚本里判失败用 exit code**，不用「输出非空」（direnv/moon 的日志噪声
   必然非空）。批量远端写操作（GitLab API 等）用 python 驱动，不用
   bash 关联数组（macOS 自带 bash 3.2 没有 `declare -A`）。

## 常见任务配方

**全栈 rebase 到最新主干**
```bash
jj git fetch
jj rebase -d 'trunk()'          # 整条分支搬上去；冗余 merge 直接 jj abandon <merge>
jj log -r 'roots(trunk()..<tip> & conflicts())'   # 找最底冲突段，从它开始解
```

**备份与回滚**
- 主安全网是 **op log**：`jj op log` 找操作点，`jj op restore <op-id>` 整仓
  回滚，`jj undo` 撤销上一步。正常操作不需要额外备份。
- 要动共享远端（force-push、批量改 MR）时做**冷归档**：`git bundle`（注意
  有的 git 版本 `bundle create` 不认裸 SHA——先 `update-ref` 到
  `refs/heads/tmp/*` 再 `--branches='tmp/*'`，产物 `bundle verify`）。
  **归档放离线文件，不要留在 origin 分支上**——一 fetch 就会把旧版本全部
  拉回视野，满屏 divergent（2026-07-29 实测）。

**推送**
```bash
jj bookmark set <name> -r <commit>   # 书签先定位
jj git push -b <name>                # sideways 移动可直接推（fetch 后）
```
远端被他人动过：先 `jj git fetch`，对照清楚再决定覆盖还是合并。

**创建 MR 前必须先把 change 搬到 `main@origin` 的 tip 上**（2026-08-10）：
GitLab fast-forward 合并要求 source 基于 target tip，叠在旧基线（哪怕是
main 的祖先）上的 MR 一推送就显示 needs rebase。
→ `jj git fetch && jj rebase -r <change> -o main@origin`，再 push。

**栈式 MR（stacked diffs）**
- 小栈手搓：每段一个书签分支，MR target = 上一段分支（栈底 = main），
  GitLab MR dependency（blocks）锁合并顺序，描述里嵌栈表。
- 大栈（>10 段或频繁重排）：评估工具接管——
  [jjpr](https://github.com/michaeldhopkins/jjpr)、
  [jj-vine](https://github.com/abrenneke/jj-vine)（支持 self-hosted GitLab）、
  [jj-ryu](https://github.com/dmmulroy/jj-ryu)。

**清理已合入的孤儿提交（`jj tidy`，保持 graph 干净）**
```bash
jj tidy        # user 级 alias = abandon 'immutable_heads().. & ~::working_copies()'
jj log -r 'immutable_heads().. & ~::working_copies()'   # 先看选择集再决定
```
- squash-merge 工作流下 MR 合入后，本地原提交成为孤儿（squash 产生新
  SHA，jj 无法自动识别内容等价）；被 forget 的 workspace 的非空提交同理
  残留。默认 log revset 显示所有 mutable 提交，孤儿形成与主线平行的长链。
- 保护集必须用 `~::working_copies()` 而非 `~::@`：`::@` 只覆盖当前
  workspace（2026-08-10 实测，见踩坑清单）。
- 配置：`jj config set --user aliases.tidy '["abandon", "immutable_heads().. & ~::working_copies()"]'`。
  选择集为空时打印 "No revisions to abandon."，exit 0。

## 踩坑清单（现象 → 根因 → 姿势）

- **`workspace add --ignore-working-copy` 部分完成**（2026-09-10）：目录和 workspace
  已创建，但更新工作副本报错，新 workspace 可能仍在空 root 子提交。
  → 不要重复创建或删除目录；先在新目录检查 `jj status`，确认是本次创建的空
  工作副本后，用 `jj new <目标 revision> -m <描述>` 完成基线设置。
  创建 workspace 不带 `--ignore-working-copy`；依据本地 CLI help 与官方
  [CLI reference](https://docs.jj-vcs.dev/latest/cli-reference/)。
- **`jj file show -r <divergent>` 静默空输出**（2026-07-29）：对歧义
  change-id 报错走 stderr，重定向一写就是 0 字节文件还毫无察觉。
  → 写文件后 `wc -l` 验非空；引用歧义 revision 用 commit id 或 `<id>/0`。
- **squash 后 @ 跑到侧线**（2026-07-29）：`jj new <中段>` 形成的 scratch
  change 是主线兄弟节点，`trunk()..@` 不再覆盖主线。→ 查全链用
  `trunk()..<书签名>`，别依赖 @ 的位置。
- **解决冲突时的「genealogy 半合并」**（2026-07-29）：3-way 标记两侧看似
  都对的文本混出第三种坏状态（字段死而复生、标题粘连）。→ 解完每段
  **必须**读结果全文关键区块，不能只信「标记清零」。
- **`jj new` 前 @ 上有别的改动**：会先快照进当前 @ 再建新 change——临时
  补丁会落错 change。→ `jj new` 前确认 @ 干净或归属正确。
- **`jj restore <path>` 默认从 @- 恢复**，不是「撤销最近编辑」；同文件有
  正当修改时不能用它兜底临时补丁。
- **`jj abandon` 撞 immutable**：提示 "would rewrite N immutable commits"
  → 确认内容已入主线/归档后 `--ignore-immutable`，别习惯性加这个 flag。
- **merged-away 段的远端分支**：`jj git push` 会随本地书签删除传播删除
  （2026-07-29 实测）；想留档先归档再删。
- **prettier/markdownlint 类检查独立于编译**：docs 改动跑文档 lint，TS 改动
  跑对应 lint——go build 全绿不能证明全绿。
- **`jj rebase -r` 后空 @ 被挂回旧基线**（2026-08-10）：对叠在旧基线上的
  change 执行 `jj rebase -r X -o main@origin`，X 正确落到了 tip，但它的空
  后代 @ 被重挂到 X 的旧父段（evolog 确认），原因未查明。连带后果：旧基线
  的 tree 没有新加的 `.gitignore` 规则，磁盘上已 untrack 的临时文件被自动
  快照重新吸进 @。→ rebase 后必须 `jj st` 确认 @ 的父段与内容；发现错挂用
  `jj new <正确父段>` + `jj abandon <错挂的 change>` 修正。⚠️ 连带删除：
  被吸进 @ 的文件在下一次工作副本切换时会被 jj 从磁盘删掉（旧 change 里
  tracked、新 change 里没有），找回用 `jj restore --from <被 abandon 的
  commit-id> <路径>`（commit id 从 evolog / op log 取）再重新 untrack。
- **`jj workspace forget` 留下孤儿提交**（2026-08-10 实测）：forget 只
  丢弃该 workspace 的空 @，非空提交全部留在仓库成为孤儿。
  → 「删 workspace = 删提交」是误解；定期 `jj tidy` 清理。
- **跨 workspace `jj abandon` 无拦截**（2026-08-10 实测）：从 ws1 abandon
  ws2 的在途提交、甚至 `ws2@` 本身，都直接成功且无警告；ws2 随后报
  working copy stale，需 `jj workspace update-stale` 恢复。从别的
  workspace 清无关孤儿则不影响本 workspace。
  → 清理类 revset 一律用 `~::working_copies()` 圈保护集，不用 `~::@`。

## 环境基线（2026-07-29 验证）

- jj **0.43.0**：`jj absorb` / `jj metaedit --update-change-id` 可用；
  **`jj fixup` 不存在**。
- 冲突标记形如 `<<<<<<< conflict 1 of 1` / `%%%%%%% diff from:` /
  `\\\\\\\ to:` / `+++++++ <change>` / `>>>>>>> ... ends`；
  消除标记即视为 resolved，再 squash 落盘。

## 参考

- 官方：[Divergent changes](https://docs.jj-vcs.dev/latest/guides/divergence/) ·
  [FAQ](https://docs.jj-vcs.dev/latest/FAQ/) ·
  [CLI reference](https://docs.jj-vcs.dev/latest/cli-reference/) ·
  [GitHub workflow](https://docs.jj-vcs.dev/latest/github/)
- 社区：[Chris Krycho: megamerges 与 jj absorb](https://v5.chriskrycho.com/journal/jujutsu-megamerges-and-jj-absorb/) ·
  [André Arko: jj part 3 workflows](https://andre.arko.net/2025/10/12/jj-part-3-workflows/) ·
  [neugierig: Understanding jj bookmarks](https://neugierig.org/software/blog/2025/08/jj-bookmarks.html)
