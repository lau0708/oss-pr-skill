---
name: oss-pr
description: End-to-end workflow for landing an open-source pull request — screen whether the repo is worth contributing to, recon its merge lane, prefer a self-found invariant bug over a raced issue, define the problem boundary, prove it with a red/green test, verify locally, open the PR with the repo's required template sections, monitor CI, handle review, and collect the interview narrative. Use when the user asks to 提 PR / 挖下一个 bug / 处理 review / 看 CI 红了 / 监控 PR / 分析某个开源项目的贡献点, or when contributing to any external GitHub repo. Repo-specific rules live in reference/.
---

# Landing an Open-Source PR

Three reasons to do this, in the user's order of priority: it deepens understanding of the
technology, it is visible to interviewers, and it is strong interview material. A merged
PR is the artifact; **the narrative is the product** — see `reference/interview-narrative.md`.

Repo-specific rules live in `reference/<repo>.md`. Read the relevant one before starting;
the spine below is repo-agnostic.

## 0. Is this repo worth the time?

Before investing days, confirm the project is alive *and* will merge outside work.

| Signal | Healthy |
| --- | --- |
| Last commit | within ~1 month |
| Issues closed : opened | ratio > 1 |
| PR response time | usually < 2 weeks |
| Release cadence | monthly or quarterly |

Find candidates with GitHub search, e.g.
`topic:ai-agent stars:>1000 pushed:>YYYY-MM-DD`. Then measure the **outside-contributor
merge rate** (step 1) — a repo can be perfectly alive and still merge only its own
maintainers' PRs, which fails this step no matter how healthy the table looks.

## 1. Recon before writing any code

- Confirm the **fork** and the **branch convention** (`<type>/<slug>`, e.g.
  `fix/memory-run-store-shared-change-position`). Push to a remote named `fork`.
- **Check for competing PRs first.** Nothing wastes more time than a fix three people
  already opened:

  ```bash
  gh api "search/issues?q=repo:OWNER/REPO+is:pr+<keywords>+in:title,body" \
    --jq '.items[] | "\(.number) \(.state) \(.title)"'
  gh pr list --repo OWNER/REPO --search "<keyword>" --state all --limit 30
  ```

- **Measure the merge lane** in one sweep: who merges, merge latency, and whether
  *self-invented* PRs from outside land at all or only issue-linked ones. This decides
  which lane you hunt in. The recipe is in `reference/deerflow.md`.
- **Decide whether to ask the maintainer before you build.**
  - An **architectural change or a new feature**: post a short issue/Discussion comment
    first — objective problem, proposed direction, "would you accept a PR like this?".
    Cheap insurance against designing something they will reject.
  - An **invariant-violation bug fix pinned by a doc**: skip it and open the PR directly.
    Both deer-flow PRs landed that way. When the contract is written down and the diff is a
    few lines, pre-asking only adds latency.

## 2. Pick the work

**Issue lane** — usually saturated, and often a *race*, not a queue. Measure it before
spending time: of the issues opened in the last 2–3 weeks, how many already have a linked
PR, and what is the median issue→first-PR delay? If most are already claimed and the
latency is hours (not days), authors are filing the issue and the PR in one motion. Stop
screening issues; the lane is closed.

**Self-found lane** — the durable one. Hunt an **internal invariant violation**: a
contract the repo documents (an `AGENTS.md`, a docstring, a reference implementation) that
one implementation honours and a sibling implementation does not. For an AI-agent project,
generate candidates with the seven-dimension audit in `reference/agent-project-audit.md`.

The fingerprint of the best bugs is **test asymmetry**: an interface with two or more
implementations where only one has a regression test for the invariant. The untested
sibling is where the bug lives.

Reusable shapes:

- **Copy-override lost an argument** — a subclass re-implements a parent method and drops
  an argument the parent passed, so the two halves of one operation consult different
  config/state. The tell is that the parent had a regression test and the override has
  none. (This shape found both deer-flow PRs.)
- **Multi-backend parity** — memory/redis, memory/sql, file/sql implementations of one
  interface. Sweep the whole family once; a swept-and-dry set rarely hides a second bug.
- **Beware seductive dead ends.** Before chasing any divergence, prove it is *reachable*
  from a production caller. A masked difference no caller can construct is a wasted day,
  however elegant it looks.

**Then define the boundary before coding** — this is what keeps the PR reviewable:

- **Core problem** — one sentence.
- **Out of scope** — 2–3 things you will deliberately *not* touch.
- **Success criteria** — how you will know it worked; quantified if possible.
- **Constraints** — do not break existing callers; keep one PR to ~≤300 lines; split only
  where a reviewer would want to verify the parts independently.

## 3. Prove it before you fix it

- Write the failing test **on pristine base** and watch it fail *for the stated reason*.
- Keep a **control assertion** on the correct implementation that passes before *and*
  after — this makes the red attributable to your change rather than to the test
  scaffolding. A reviewer reproduced exactly this on deer-flow #5703.
- Cover three things: the **happy path**, the **boundary** (empty/oversized/failure input),
  and **compatibility** (the old usage still behaves the same). The control assertion *is*
  the compatibility case.
- If a fallback can fail in either direction, pin **both** directions.
- Record the exact red assertion text (`AssertionError: assert 'installed' == 'blocked'`)
  — it goes in the PR body.

## 4. Fix minimally

One production line beats a refactor. Do not tidy neighbouring code; blast radius is a
review cost. Threading a parameter through three call sites is fine when the invariant
demands it, and nothing beyond that. Prefer extending over modifying; if you must modify a
shared function, change only what the invariant requires.

## 5. Verify locally, exactly as CI does

- **Establish the baseline first:** confirm the base branch is green before you change
  anything. Then any later failure is attributable.
- Run the lint/format commands **literally** as CI runs them (deer-flow:
  `cd backend && make lint`, and CI additionally enforces `ruff format --check`).
- Run the **targeted** test files, not just a smoke subset.
- If the environment is broken (a dependency that won't import), do **not** chase a green
  full suite you cannot have. Run the failing subset against pristine base and against
  your branch, and show **identical counts**. Put that table in the PR body.

## 6. Commit and push

- Conventional commit: `fix(scope): ...`.
- Split into the smallest number of commits a reviewer can verify independently — usually
  one, two when a review follow-up is a genuinely separate idea. These repos squash-merge,
  so the split is for *review*, not for history; over-splitting is noise.
- Push to `fork`.

## 7. Open the PR

- Fill the repo's **own** template. Never delete a required section — look for a "Bug fix
  verification" / "AI assistance" style section and fill it honestly.
- Body shape that has worked:
  - **Why / Problem** — the invariant, with `file:line` for both the correct *and* the
    divergent call site.
  - **What changed / Solution** — the minimal change, and the case that deliberately does
    *not* change.
  - **Bug fix verification** — red assertion on base, green on the branch, plus the control
    that passes in both.
  - **Validation / Testing** — commands and their output; the baseline table if the env is
    broken.
  - **Notes for reviewer** — flag deliberate decisions and where you want scrutiny. (On
    #5703 this is where I said no Surface-area checkbox matched the path actually changed —
    better to say so than let a reviewer hunt for the mismatch.)
  - **AI assistance** — disclose the tool and state what you verified yourself.
- Re-read your own diff before opening. You are the first reviewer.

## 8. Watch and respond

Keep these three states distinct — never report "on track" without `gh pr checks <N>`:

- **BLOCKED on you** — unsigned CLA. Needs the *user's own* login; you cannot clear it.
  It is a silent, indefinite stall if nobody notices.
- **Waiting on a maintainer** — workflow approval (fork PRs often need one click before
  *any* CI runs) or a required review. `mergeStateStatus: BLOCKED` alone usually means
  "awaiting required review", not "broken".
- **Genuinely broken** — read the failing job before blaming your diff. Check whether the
  failure is main-side drift: `git log origin/main -- <the failing file>`. Merging `main`
  in is often the entire fix.

Review handling:

- Reply to inline comments. Implement scoped follow-ups and **bundle them into the same
  PR** unless the reviewer asks to split.
- If you push after the reviewer verified a specific SHA, **say so plainly** — good
  reviewers read the cited files at the head SHA and will notice it moved.
- Match their rigor: if they reproduced red/green in a clean worktree, verify your *new*
  test actually fails when you break the thing it pins. A test that passes under a
  deliberate regression is worthless.

Use `script/pr-watch.sh` to watch PRs for maintainer activity and CI transitions instead of
polling by hand.

## 9. Collect the narrative

Maintain the running note described in `reference/interview-narrative.md` as you go — the
invariant in one sentence, the decisions and the rejected alternatives, the obstacles and
how you escaped them, and the evidence quoted verbatim (red assertion text, `file:line`,
and the maintainer's own review sentences). Reconstructing this later produces generic
answers; capturing it at each transition produces specific ones.

## 10. Report to the user, terse

What changed (commit + branch), current PR state, and what is next. Flag blockers
explicitly and name who can clear them.

## Cross-cutting discipline

- **Stop and ask, do not silently expand.** Stop when the fix needs files outside the
  agreed boundary, when the change cannot be made without breaking a caller, when there are
  two reasonable designs with a real tradeoff, or when a new dependency is needed. Adapting
  pseudocode to the real code, adding error handling the plan omitted, and differing test
  mechanics are all fine to just do — but say what you did.
- An unverifiable claim is worse than no claim. If you cannot test a behaviour, say so.
- Distinguish "my change broke it" from "it was already broken" with evidence (baseline
  counts, `git log origin/main -- <file>`), never with a guess.
- After a PR merges, update the user's memory with what was *non-obvious* — maintainer
  behaviour, lane saturation, environment breakage. Not file paths or conventions the repo
  already records.
- Adding a new repo is one file: `reference/<repo>.md` plus a row in `script/pr-watch.sh`.
