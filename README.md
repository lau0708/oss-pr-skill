# oss-pr

**A [Claude Code](https://claude.com/claude-code) skill that turns "I should contribute to open source" into a repeatable, evidence-driven process.**

It has been used to land real fixes in [deer-flow](https://github.com/bytedance/deer-flow) — an 83k★ LangGraph agent project — twice, plus a third still in review.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-8A63D2)](https://claude.com/claude-code)
![Merged into deer-flow](https://img.shields.io/badge/merged%20into%20deer--flow-2-brightgreen)

---

## Results

| PR | Change | Outcome | Time to merge |
| --- | --- | --- | --- |
| [#5663](https://github.com/bytedance/deer-flow/pull/5663) | `fix(runtime)`: share one change position across an atomic thread operation | **Merged** | ~12 h |
| [#5703](https://github.com/bytedance/deer-flow/pull/5703) | `fix(skills)`: resolve the user-scoped install content scan from its own config | **Merged** | ~8 h |
| [#5998](https://github.com/bytedance/deer-flow/pull/5998) | `fix(channels)`: grant sandbox read bits to Feishu/DingTalk inbound uploads | In review | — |

All three were **self-initiated** — no issue was filed, no maintainer was pre-asked. Each is
a small diff (~110–145 lines including tests) that fixes a contract the repo had already
documented and one implementation had silently broken.

## Why this exists

Most first-time contributions to a large project don't die because the code is wrong. They
die earlier: the contributor picked an issue three other people had already claimed, wrote a
fix without a failing test, made a claim they couldn't verify, and opened a PR that a
maintainer had no reason to trust.

This skill encodes the opposite process — the one that produced the three PRs above:

- **Hunt bugs, don't queue for issues.** In fast-moving repos the issue lane is a race, not
  a queue — authors file the issue and open the PR in one motion. The durable lane is
  finding an *internal invariant violation*: a contract the repo documents that one
  implementation honours and a sibling does not.
- **Prove it before you fix it.** The failing test goes red on pristine `main`, *for the
  stated reason*, with a control assertion that passes before and after — so the red is
  attributable to the change, not to the test scaffolding.
- **Evidence beats guesses.** When `main` itself is broken locally, don't chase a green suite
  you can't have. Diff the failure set against a pristine worktree and show identical counts.

## The three ideas that do the work

**1. Test asymmetry is the bug-finder.** An interface with two or more implementations where
only one has a regression test for the invariant — the untested sibling is where the bug
lives. This single heuristic found both merged PRs.

**2. Bugs have reusable shapes.** Two are encoded so far:

- *Copy-override loses an argument* — a subclass re-implements a parent method and silently
  drops something the parent passed, so the two halves of one operation consult different
  state.
- *One side-effect owner, two handoff styles* — a cross-cutting side-effect lives in a shared
  ingress path; implementations that re-implement the work instead of delegating never get it.

**3. Reachability is a gate, not an afterthought.** An elegant divergence that no production
caller can construct is a wasted day. Prove it's reachable before you chase it.

## What it covers

| Step | |
| --- | --- |
| 0 | Screen repo fit — alive *and* merges outside contributions |
| 1 | Recon — competing-PR check, merge-lane measurement, when to pre-ask |
| 2 | Pick the work — self-found invariant over a raced issue; define the boundary |
| 3 | Prove it — red on base for the stated reason, plus a control assertion |
| 4 | Fix minimally — one production line beats a refactor |
| 5 | Verify locally, exactly as CI does; baseline-compare if the env is broken |
| 6–7 | Commit conventionally; open the PR in the repo's own template |
| 8 | Watch CI and review — three distinct states, never "on track" without evidence |
| 9–10 | Collect the interview narrative; report terse |

## Install

```bash
git clone https://github.com/lau0708/oss-pr-skill ~/.claude/skills/oss-pr
```

Claude Code picks it up automatically and triggers on requests like *"提 PR"*, *"find the
next bug in \<repo\>"*, *"handle the review"*, *"CI is red"*, or *"watch the PR"*.

## Layout

```
SKILL.md                         # the repo-agnostic spine (steps 0–10)
reference/agent-project-audit.md # 7 dimensions to audit an agent project for real bugs
reference/interview-narrative.md # how to turn the work into interview material
reference/deerflow.md            # worked appendix: bytedance/deer-flow
script/pr-watch.sh               # table-driven PR watcher
```

Adding a repo is one file: `reference/<repo>.md` with its norms, merge lane, swept-and-dry
areas, reusable bug shapes, and CI mechanics.

## `pr-watch.sh`

```bash
# edit the WATCH array first: "owner/repo number label"
bash script/pr-watch.sh
```

Each stdout line is one notification: human maintainer comments and reviews (bots, the CLA
app, and your own comments are filtered out), CI state transitions, and a final
merged/closed line. Polls every 60s. Written to be portable to macOS's stock bash 3.2 — no
associative arrays, no `mapfile` — because that's the shell a lot of contributors actually
have.

## Design notes

- **It stops and asks rather than silently expanding scope.** Fix needing files outside the
  agreed boundary, a change that would break a caller, two defensible designs with a real
  tradeoff, a new dependency — all halt for a decision. Adapting pseudocode and differing
  test mechanics do not.
- **An unverifiable claim is treated as worse than no claim.** If a behaviour can't be
  tested, the skill says so instead of asserting it.
- **One commit per independently verifiable idea**, not per file — these repos squash-merge,
  so the split exists for the reviewer.

## 中文摘要

**oss-pr** 是一个 Claude Code skill，把「给开源项目提 PR」变成一套可复现、以证据驱动的流程。
它已经用于向 **deer-flow**（83k★ 的 LangGraph Agent 项目）提交真实修复：两个 PR 已合并
（分别约 8 小时、12 小时内合并），第三个在审核中。

核心不是代码，而是方法：

- **自己挖 bug，不排队抢 issue** —— 在活跃仓库里 issue 赛道是竞速而非队列；可持续的赛道是找
  *内部不变量违反*：仓库已文档化的契约，某个实现遵守、它的兄弟实现不遵守。
- **先证明再修复** —— 失败的测试要在干净的 `main` 上、因为**声称的那个原因**变红，并配一个修复
  前后都通过的对照断言，让「红」可归因于改动本身。
- **证据优先于猜测** —— 本地环境坏掉时不去追一个不可能拿到的全绿，而是与干净 worktree 对比失败
  集合，给出完全一致的计数。

三个真正起作用的想法：**测试不对称**（同一接口只有一个实现有回归测试，没被测的兄弟实现就是
bug 所在）、**可复用的 bug 形状**（copy-override 丢参数 / 一个副作用两种交接方式）、以及
**可达性是准入门槛**（优雅但没有任何生产调用路径能触发的差异，不值得追）。

安装：`git clone https://github.com/lau0708/oss-pr-skill ~/.claude/skills/oss-pr`

## License

[MIT](LICENSE)
