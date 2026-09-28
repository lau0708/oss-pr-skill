# deer-flow（`bytedance/deer-flow`）

LangGraph 超级 Agent：Python 后端（`backend/`）+ Next.js 前端（`frontend/`）。
实务做法是 fork 这个仓库、把你的 fork 加成 remote（例如 `fork`），然后每个改动都从
`origin/main` 切分支。

各模块的深度指引在仓库自己的 `AGENTS.md` 里（根文件 import 了 `backend/AGENTS.md`；动任何子系统
之前先读最近的那份）。

## 决定能否合并的仓库规矩

- **TDD 是强制的** —— 红色测试随修复一起提交，reviewer 会自己再跑一遍
  base 上红 / 修复后绿 的验证。
- `cd backend && make lint`（ruff check）必须干净，CI 还额外强制
  `ruff format --check .`。推送前两个都跑。
- PR 模板有**必需**的「Bug fix verification」和「AI assistance」章节。不要删，用真实证据和真实
  披露去填。
- 规范式提交信息。

## 合并通道（2026-09-22 实测）

- **有一位维护者实际上就是唯一的把关人**（最近 100 个已合并 PR 里合了 100/100）；**另一位
  reviewer** 与他并行工作。首个 review 通常在开 PR 后约 1.5 小时到达。
- **那 100 个里有约 93 个来自非维护者账号，32 个是自己发明**、而不是挂靠 issue 的。所以自主发现
  赛道在这里是可行的 —— issue 赛道不行。
- **issue 赛道是关闭的，不只是饱和。** 2026-09-08 以来开的 100 个 issue 里有 90 个已经挂了 PR，
  首个 PR 的延迟是 **0–1.4 小时**，因为少数几个常客是在同一个动作里既提 issue 又提 PR。不要在
  筛 issue 上花时间。
- 竞品 PR 检查：
  `gh api "search/issues?q=repo:bytedance/deer-flow+is:pr+<term>+in:title,body"`。
- **不变量 bug 修复不要预先询问。** #5663 和 #5703 都没有先开 issue、也没有先发「我可以做吗」的
  评论；两个都是针对文档钉死的契约直接开 PR，并在两天内合并。把预先询问留给新功能或架构级改动
  —— 那种形状才会被「先设计再否决」。

## 已扫干净，不要重复扫

多后端同构性家族，已检查并排除：`runtime/events/store`（memory/jsonl/db）、
`runtime/checkpoint_cache`（memory/redis）、`runtime/stream_bridge`（memory/redis）、
`persistence/thread_meta`（memory/sql）、`persistence/agents`（file/sql）、
`persistence/managed_subagents`（file/sql）。只有 `runtime/runs/store` 有真 bug（已在 #5663 修）。

已知死胡同，两个都**可证明不可达** —— 不要重复追：

- `ThreadMetaStore.search` 在 memory 后端跳过 key 校验，而 `sql.py` 里是跳过并抛错 —— 被掩盖了，
  因为 `routers/threads.py` 用 `JsonMatch.__init__` 用的*同一批* helper 校验了每个 key/value。
- `event_types=[]` 在 db 后端意味着「不过滤」，在 memory/jsonl 里意味着「什么都不匹配」—— 没有
  任何生产调用方能构造出 `[]`。
- `AgentStore.delete` 在 db 后端从不返回 `"legacy"` 结果是**有意**的（那个后端没有 legacy 共享
  布局）。同样，某些路由上 authz 的 `require_existing` 缺口也是刻意的，或被 `_owned_batch` 覆盖。

## 这里可复用的 bug 形状

**形状 1 —— 复制式覆写丢了参数。** 子类**复制式覆写**父类方法，悄悄丢掉了父类传进去的一个参数，
导致同一个安装/操作的两道闸门不一致。

- #5703：`UserScopedSkillStorage.ainstall_skill_from_archive` 重新实现了父类方法，并从
  `_scan_skill_archive_contents_or_raise(...)` 里丢掉了 `app_config=self._app_config`，于是内容
  扫描退回到进程全局的 `get_app_config()`，而继承来的归档预检仍然读 `self._app_config`。同一次
  安装的两道闸门可能对 `skill_scan.enabled` 得出不同结论。
- 怎么找下一个：grep 那些覆写里重新实现了父类方法体的类（重复的 `ainstall_*` / `async def`
  方法体、没有 `super().`），然后把参数列表与父类对比。特征是**测试不对称** —— 父类有开关式的
  回归测试，覆写没有。

**形状 2 —— 一个副作用，两种交接方式。** 某个横切副作用由*共享的入口路径*统一施加；有些实现
走这条路径，有些自己重实现，于是只有前者拿到了这个副作用。

- #5998：`ChannelManager._ingest_inbound_files` 写入入站附件后施加沙箱读权限位
  （`S_IRGRP | S_IROTH`），让非 root 沙箱能读 bind-mount 进来的文件。Telegram 通过
  `INBOUND_FILE_CONTENT_KEY` 把字节交给 manager，从而继承了这个副作用；Feishu 和 DingTalk
  自己持久化字节并返回一个虚拟路径，绕过了写入*和*权限位 —— 所以在 AIO/Docker 沙箱模式下，它们的
  附件静默地不可读。
- 怎么找下一个：找一个在共享入口路径里执行的副作用，然后 grep 那些自己重实现持久化、而不是委托
  给入口路径的实现。用 `git log -S "<helper>" -- <file>` 引用来源，说明哪个兄弟实现早就修过了。

相关，但**不是**安全闸门 —— 写正文时把它们分开：逐文件 LLM 扫描（`scan_skill_content`）读
`app_config` 只是为了 `skill_evolution.moderation_model_name` 和模型构造。`skill_scan.enabled`
并不管它。

## Fork PR 的 CI 机制

- `license/cla` 是一个 **cla-assistant GitHub App** 检查，**没有**写在 `CONTRIBUTING.md` 里 ——
  在文档里 grep 「CLA」会错误地让人以为不需要。要去看 PR 的 check runs。未签时，它是一个无声的
  无限期停滞，**只有账号本人能清**（用他/她自己的 GitHub 登录，在
  `https://cla-assistant.io/bytedance/deer-flow?pullRequest=<N>`）。
- fork 的 `pull_request` 工作流会停在 `action_required`，直到某位维护者点了「Approve and run
  workflows」。所以一个 fork PR 可能在很长时间里只有 CLA + 机器人检查；那**不是**失败。维护者
  自己的分支会立刻运行。推论：推送前先在本地把套件跑掉 —— 在那之前它是唯一的证据。
- fork PR 上 `backend-unit-tests (N)` 失败**经常是 main 侧漂移，不是你**。#5703 挂在
  `test_agent_guidance_check.py`（`backend/app/gateway/AGENTS.md` 是 49155 字节，预算是
  49152），一小时内在 main 上被 #5725 修掉。在断定是你的 diff 造成之前，先查
  `git log origin/main -- <the failing file>`；把 `main` 合进来往往就够了。
  - `normalized_utf8_size` 会把 CRLF 归一成 LF，所以 CI 报的数*大于*你本地 `wc -c` 时，意思是
    文件内容真的不同 —— 不是换行符的假象。

## reviewer 的风格

快（约 1.5 小时）、真诚、具体。这位 reviewer 会自己重跑套件、**在精确 head SHA 的干净 worktree
里**复现红/绿，并在该 ref 上确认你引用的文件。然后他会留下**一条有边界的行内后续建议**，而不是
一句含糊的评论，并且明确区分 CI 失败是你造成的还是不是。两个推论：

- 他会按 head SHA 去读你引用的文件，所以如果你在他的验证之后又推了提交，要说出来。
- 后续建议会以「顺手加一下也好」的语气出现 —— 实现它，并并进同一个 PR。

## 本地环境坑（作者的 macOS 机器）

- `cryptography` 的 Rust binding dlopen 失败（`symbol not found in flat namespace
  '_EVP_DigestSqueeze'`）。这会让 `backend/tests/` 下约 61 个文件在**收集阶段**就挂掉，还有许多
  在运行时因传递依赖 `cryptography` 而失败。**本地 `make test` 全绿是不可能的 —— 不要去追。**
  改为：跑目标文件，然后把同一批失败子集跑在干净的 `origin/main` 上比计数。计数一致 = 早已存在。
- **基线技巧：** 在 `git worktree` 里跑干净树（`git worktree add --detach /tmp/base
  origin/main`），只把改过的测试文件拷进去，用 `comm` 对比 `^FAILED` 列表。它的 pytest 用主
  venv 跑（`VIRTUAL_ENV=<main>/.venv <main>/.venv/bin/python -m pytest`），这样 `uv` 不会去
  同步一个新环境。对已提交的分支，`git switch --detach origin/main` 也行（venv 是 gitignore 的，
  切分支不影响它）。
- **cwd 漂移：** Bash 工具的 cwd 会跨调用持续，有些命令会 `cd` 到仓库根。永远加前缀
  `cd .../backend &&` —— 在仓库根跑 `uv run pytest tests/` 会静默地跑*根目录*的 `tests/`（用的
  还是另一个 python），而不是 `backend/tests/`。
- **zsh 不会对未加引号的标量做词分割。** `args=$(awk ...)` 之后 `$args` 会把整串当一个参数传。
  用 zsh 数组（`args+=(--flag=x)`），它会按元素展开。
- 把一次长 pytest 重定向到文件会让 stdout 变成块缓冲，看起来像卡住。用 `-v`（每个测试一行、
  行缓冲）来看进度。

## 已落地的实例

- **#5663** `fix(runtime): share one change position across an atomic thread operation` ——
  开 PR 后约 2 天合并。完整 CI 14 通过 / 4 跳过 / 0 失败。
- **#5703** `fix(skills): resolve the user-scoped install content scan from its own config` ——
  两个提交：一行修复（+ `TestInstallScanConfigParity`），以及第二个提交把 `app_config` 穿进逐
  文件 LLM 扫描（reviewer 的行内后续建议）。在 `ae2dadd4` 上被批准，**19 秒后**合并。

这条赛道端到端是通的：自主发现内部不变量 bug → 文档钉死的契约 → 红后绿的测试 → 合并，两次都在
两天内。在 reviewer 验证了较早 SHA 之后才推的后续提交被原样接受了 —— reviewer 说过它
「not blocking」，不需要拆成单独的 PR。

**这里的合并是 squash 合并。** 用 `git log --oneline --grep="#<N>" origin/main` 验证一个 PR
是否落地 —— `git merge-base --is-ancestor <your-head> origin/main` 即使合并成功也会返回 NO，
因为 squash 建了一个新提交。不要从这个祖先检查得出「没合并」的结论。
