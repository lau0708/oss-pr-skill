# oss-pr

A [Claude Code](https://claude.com/claude-code) skill for landing pull requests on
open-source repos you don't maintain — end to end, from deciding whether a repo is worth
the time to collecting the story afterwards.

It is opinionated about one thing: **a merged PR is the artifact, but the narrative is the
product.** The workflow exists to produce both, with evidence you can point at.

## What it covers

| Step | What it does |
| --- | --- |
| 0 | Screen repo fit — is it alive *and* does it merge outside contributions |
| 1 | Recon — competing-PR check, merge-lane measurement, when to pre-ask a maintainer |
| 2 | Pick the work — prefer a self-found invariant bug over a raced issue |
| 3 | Prove it — the failing test goes red on base *for the stated reason* |
| 4 | Fix minimally |
| 5 | Verify locally — baseline-compare when a green suite isn't attainable |
| 6 | Commit and push |
| 7 | Open the PR with the repo's required template sections |
| 8 | Watch CI and respond to review |
| 9 | Collect the interview narrative |
| 10 | Report |

## Install

Copy the directory into your skills folder:

```bash
git clone https://github.com/lau0708/oss-pr-skill ~/.claude/skills/oss-pr
```

Claude Code picks it up automatically. It triggers on requests like "提 PR", "find the next
bug in \<repo\>", "handle the review", "CI is red", or "watch the PR".

## Layout

```
SKILL.md                        # the repo-agnostic spine
reference/agent-project-audit.md # 7 dimensions to audit an agent project for real bugs
reference/interview-narrative.md # how to turn the work into interview material
reference/deerflow.md            # worked appendix: bytedance/deer-flow
script/pr-watch.sh               # table-driven PR watcher (macOS bash 3.2-safe)
```

`SKILL.md` is the spine; `reference/<repo>.md` holds repo-specific rules. Read the relevant
one before starting. To add a repo, write `reference/<repo>.md` with its norms, merge lane,
swept-and-dry areas, reusable bug shapes, and CI mechanics.

## The two bug shapes it teaches

1. **Copy-override loses an argument** — a subclass re-implements a parent method and
   silently drops something the parent passed, so two gates of one operation disagree. The
   tell is a **test asymmetry**: the parent has a regression test, the override doesn't.
2. **One side-effect owner, two handoff styles** — a cross-cutting side-effect lives in a
   shared ingress path; implementations that re-implement the work instead of delegating
   never get it.

## pr-watch.sh

```bash
# edit the WATCH array first: "owner/repo number label"
bash script/pr-watch.sh
```

Each stdout line is one notification: human maintainer comments and reviews (bots, the CLA
app, and your own comments are filtered out), CI state transitions, and a final
merged/closed line. Polls every 60s.

## Notes

- No license file yet — add one before relying on this for anything.
- `reference/deerflow.md` is a worked example with real PR numbers; maintainer and
  contributor handles are generalized.
