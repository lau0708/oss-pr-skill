# oss-pr

**一个 Claude Code skill：把「我应该给开源做点贡献」变成一套可复现、以证据驱动的流程。**

它已被用于向 [deer-flow](https://github.com/bytedance/deer-flow)（83k★ 的 LangGraph Agent 项目）提交真实修复 —— 两个已合并，第三个在审核中。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-8A63D2)](https://claude.com/claude-code)
![Merged into deer-flow](https://img.shields.io/badge/merged%20into%20deer--flow-2-brightgreen)

---

## 实战成果

| PR | 改动 | 结果 | 合并耗时 |
| --- | --- | --- | --- |
| [#5663](https://github.com/bytedance/deer-flow/pull/5663) | `fix(runtime)`：让原子线程操作共享同一个变更位置 | **已合并** | 约 12 小时 |
| [#5703](https://github.com/bytedance/deer-flow/pull/5703) | `fix(skills)`：用户级安装的内容扫描改从自身配置解析 | **已合并** | 约 8 小时 |
| [#5998](https://github.com/bytedance/deer-flow/pull/5998) | `fix(channels)`：为 Feishu/DingTalk 入站附件补上沙箱读权限位 | 审核中 | — |

三个都是**自主发现**的：没有提 issue，也没有事先询问维护者。每个 diff 都很小（含测试约 110–145
行），修的却是仓库自己已经写进文档、而某个实现悄悄违反了的契约。

## 为什么做这个

大多数第一次给大型项目提 PR 的人，不是死在代码写错，而是死得更早：抢了一个已经被三个人认领的
issue，改完没有失败测试，做了无法验证的断言，最后提了一个维护者没有理由相信的 PR。

这个 skill 固化的是一套相反的做法 —— 也就是产出上面三个 PR 的那套：

- **自己挖 bug，不排队抢 issue。** 在活跃仓库里，issue 赛道是竞速而不是队列：作者往往在同一时间
  既提 issue 又提 PR。可持续的赛道是找**内部不变量违反** —— 仓库已经文档化的某个契约，一个实现
  遵守，它的兄弟实现不遵守。
- **先证明，再修复。** 失败的测试要在干净的 `main` 上、因为**声称的那个原因**变红，并配一个修复
  前后都通过的对照断言 —— 这样「红」才能归因于你的改动，而不是测试脚手架本身。
- **证据优先于猜测。** 当 `main` 在本机就是坏的，不要追一个拿不到的全绿。把失败集合与干净
  worktree 对比，给出完全一致的计数。

## 三个真正起作用的想法

**1. 测试不对称就是 bug 定位器。** 同一个接口有多个实现，其中只有一个为该不变量写了回归测试 ——
没被测到的那个兄弟实现，就是 bug 所在。仅凭这一条启发式，就找到了两个已合并的 PR。

**2. bug 有可复用的形状。** 目前固化了两种：

- **复制式覆写丢了参数** —— 子类重新实现父类方法时，悄悄漏掉了父类传进去的东西，导致同一个操作
  的两半读取了不同的配置/状态。
- **一个副作用，两种交接方式** —— 某个横切副作用由共享的入口路径统一施加；那些选择自己重实现、
  而不是委托给入口路径的实现，就永远拿不到它。

**3. 可达性是准入门槛，不是事后补充。** 一个再优雅、但没有任何生产调用路径能构造出来的差异，
追一天也是白费。先证明可达，再决定要不要追。

## 覆盖的流程

| 步骤 | 做什么 |
| --- | --- |
| 0 | 判断这个仓库值不值得投入 —— 还活着，**并且**会合并外部贡献 |
| 1 | 侦察 —— 查竞品 PR、量化合并通道、判断要不要先问维护者 |
| 2 | 选活 —— 自主发现的不变量 bug 优先于被抢的 issue；先划定边界 |
| 3 | 先证明 —— 在 base 上因为声称的原因变红，并配对照断言 |
| 4 | 最小修复 —— 一行生产代码胜过一次重构 |
| 5 | 本地按 CI 的方式验证；环境坏了就做基线对比 |
| 6–7 | 规范提交；按仓库自己的模板开 PR |
| 8 | 盯 CI 和 review —— 三种状态严格区分，没有证据不说「一切正常」 |
| 9–10 | 沉淀面试叙事；向用户简报 |

## 怎么使用

### 安装

**Claude Code**

```bash
git clone https://github.com/lau0708/oss-pr-skill ~/.claude/skills/oss-pr
```

装到 `~/.claude/skills/` 下，Claude Code 下次启动就会自动加载。也可以放进某个仓库的
`.claude/skills/`、只对那个项目生效 —— 但优先级是 **企业 > 个人 > 项目**，个人级的同名 skill
会盖掉项目级的。

**Codex**

```bash
git clone https://github.com/lau0708/oss-pr-skill ~/.codex/skills/oss-pr
```

`~/.codex/skills/<name>/` 下的技能会被自动发现，不用改 `config.toml`。也可以用 Codex 自带的
安装器：

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo lau0708/oss-pr-skill --path . --name oss-pr
```

仓库里带了 `agents/openai.yaml`，就是给 Codex 用的（同一份 `SKILL.md` 两边通用）。

### 两种触发方式

- **自动触发** —— 按 `SKILL.md` 的 `description` 匹配你的说法，不用记名字。下面这些都会命中。
- **手动调用** —— 直接敲 `/oss-pr`。想确认装没装上，用 `/skills` 看列表。

### 可以这么跟它说

| 你说 | 它做什么 |
| --- | --- |
| 「给 bytedance/deer-flow 挖一个能合进去的 bug」 | 先侦察合并通道和竞品 PR，再按七个维度找不变量违反，给你一份排好序的候选 |
| 「这个 bug 帮我做成 PR」 | 划边界 → 写红测试 → 最小修复 → 本地按 CI 验证 → 按仓库模板开 PR |
| 「看下我那个 PR 的 CI」 | 用 `gh pr checks` 区分「卡在你」「在等维护者」「真的坏了」，而不是凭感觉说正常 |
| 「处理一下 review」 | 回复行内评论、把有边界的后续改动并进同一个 PR |
| 「监控这个 PR」 | 起 `pr-watch.sh`，只在维护者活动和 CI 状态迁移时叫你 |
| 「把这段经历整理成面试叙事」 | 按七段式，用逐字证据（红色断言、`file:line`、维护者原话）填 |

### 一次大概是这样走的

1. 你给出目标仓库和意图。它先做侦察 —— 包括查有没有人已经提过同样的 PR。**这一步经常的结论是
   「换个目标」**，但那也比写完代码才发现撞车好。
2. 确定候选后**先划定边界**：核心问题一句话、明确不碰的 2–3 件事、成功标准。然后才动代码。
3. 失败的测试先写、先在干净的 `main` 上因为声称的原因变红，再改生产代码。红/绿两段证据都会写进
   PR 正文。
4. 开 PR 前它会重读自己的 diff。
5. 之后是盯 CI、处理 review；你随时可以问「现在什么状态」。

它会在该问的地方停下来问你 —— 修复要动到约定边界外的文件、改动会破坏调用方、有两种各有真实代价
的合理设计、需要新依赖，这些都会先问，不会自己扩大范围。

## 目录结构

```
SKILL.md                          # 与仓库无关的主干流程（步骤 0–10）
agents/openai.yaml                # Codex 侧清单（display_name / default_prompt）
references/agent-project-audit.md # 审计 Agent 项目真实 bug 的 7 个维度
references/interview-narrative.md # 如何把这段工作变成面试素材
references/deerflow.md            # 实战附录：bytedance/deer-flow
scripts/pr-watch.sh               # 表驱动的 PR 监控脚本
```

新增一个仓库只需一个文件：`references/<仓库>.md`，写它的规矩、合并通道、已排查干净的区域、
可复用的 bug 形状，以及 CI 机制。

## `pr-watch.sh`

```bash
# 先编辑 WATCH 数组："owner/repo number label"
bash scripts/pr-watch.sh
```

每行 stdout 就是一条通知：来自真人的维护者评论与 review（机器人、CLA 应用和你自己的评论都会被
过滤掉）、CI 状态迁移，以及最后一行的已合并/已关闭。每 60 秒轮询一次。刻意写成兼容 macOS 自带的
bash 3.2 —— 不用关联数组、不用 `mapfile` —— 因为那正是很多贡献者手上真实可用的 shell。

## 设计取舍

- **它会停下来问你，而不是悄悄扩大范围。** 修复需要动到约定边界外的文件、改动会破坏调用方、
  有两种各有真实代价的合理设计、需要引入新依赖 —— 这些都会停下来等决定。而照着伪代码适配真实
  代码、补上计划里漏掉的错误处理、调整测试写法，则可以自行处理，只需说明你做了什么。
- **无法验证的断言，比没有断言更糟。** 某个行为如果测不了，skill 会选择直说，而不是硬写一句结论。
- **每个「可独立验证的想法」一个 commit**，而不是每个文件一个 —— 这些仓库是 squash 合并，
  拆分的意义在于让 reviewer 能分开验证。

## English Abstract

**oss-pr** is a [Claude Code](https://claude.com/claude-code) skill that turns "I should
contribute to open source" into a repeatable, evidence-driven process. It has been used to
land real fixes in [deer-flow](https://github.com/bytedance/deer-flow), an 83k★ LangGraph
agent project — two merged (in ~8 h and ~12 h), a third in review. All three were
self-initiated, with no issue filed and no maintainer pre-asked.

The value isn't the code, it's the method: hunt invariant violations instead of queuing for
issues; make the failing test go red on pristine `main` *for the stated reason*, with a
control assertion that passes before and after; and prefer evidence over guesses when the
local environment is broken.

Three ideas carry the weight: **test asymmetry** (of several implementations of one
interface, the one without a regression test is where the bug lives), **reusable bug
shapes** (a copy-override that silently drops an argument; a side-effect owned by a shared
ingress path that self-persisting implementations never inherit), and **reachability as a
gate** (an elegant divergence no production caller can construct is a wasted day).

Install by cloning into `~/.claude/skills/`; it then auto-triggers on requests like "find the
next bug in \<repo\>" or "handle the review", or can be invoked explicitly with `/oss-pr`.

## License

[MIT](LICENSE)
