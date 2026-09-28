# deer-flow (`bytedance/deer-flow`)

LangGraph super-agent: Python backend (`backend/`) + Next.js frontend (`frontend/`).
The practical setup is to fork the repo and add your fork as a remote (e.g. `fork`),
then branch off `origin/main` per change.

Deep per-module guidance lives in the repo's own `AGENTS.md` files (root imports
`backend/AGENTS.md`; read the nearest one before touching a subsystem).

## Repo norms that gate a merge

- **TDD is mandatory** — the red test ships with the fix, and reviewers re-run the
  red-on-base / green-on-fix check themselves.
- `cd backend && make lint` (ruff check) must be clean, and CI additionally enforces
  `ruff format --check .`. Run both before pushing.
- The PR template has **required** "Bug fix verification" and "AI assistance" sections.
  Do not delete them; fill them with real evidence and real disclosure.
- Conventional commit messages.

## Merge lane (measured 2026-09-22)

- **One maintainer is effectively the sole gatekeeper** (merged 100/100 of the last 100
  merged PRs); **a second reviewer** works alongside them. First review lands ~1.5 h after
  opening.
- **~93 of those 100 were non-maintainer accounts, and 32 were self-invented** rather than
  tied to an issue. So the self-found lane is viable here — the issue lane isn't.
- **The issue lane is closed, not merely saturated.** 90 of the 100 issues opened since
  2026-09-08 already had a linked PR, and first-PR latency was **0–1.4 hours**, because a
  handful of repeat contributors file the issue and open the PR in one motion. Do not spend
  time screening issues.
- Competing-PR check:
  `gh api "search/issues?q=repo:bytedance/deer-flow+is:pr+<term>+in:title,body"`.
- **Do not pre-ask for an invariant bug fix.** Neither #5663 nor #5703 posted an issue or a
  "mind if I…" comment first; both were opened as PRs against a doc-pinned contract and
  merged in under two days. Reserve the pre-ask for a new feature or an architectural
  change, which is the shape that gets designed-then-rejected.

## Swept and dry — do not re-sweep

Multi-backend store-parity families checked and cleared: `runtime/events/store`
(memory/jsonl/db), `runtime/checkpoint_cache` (memory/redis), `runtime/stream_bridge`
(memory/redis), `persistence/thread_meta` (memory/sql), `persistence/agents` (file/sql),
`persistence/managed_subagents` (file/sql). Only `runtime/runs/store` had a real bug
(fixed in #5663).

Known dead ends, both **provably unreachable** — do not re-chase:

- `ThreadMetaStore.search` skips key validation in the memory backend but skips-and-raises
  in `sql.py` — masked because `routers/threads.py` validates every key/value with the
  same helpers `JsonMatch.__init__` uses.
- `event_types=[]` means "no filter" in the db backend but "match nothing" in
  memory/jsonl — no production caller can build `[]`.
- `AgentStore.delete` never returning the `"legacy"` outcome on the db backend is
  **intentional** (that backend has no legacy shared layout). Likewise the authz
  `require_existing` gaps on some routes are deliberate or covered by `_owned_batch`.

## Reusable bug shapes here

**Shape 1 — copy-override loses an argument.** A **copy-override of a parent method that
silently loses an argument the parent passed**, producing one install/operation whose two
gates disagree.

- #5703: `UserScopedSkillStorage.ainstall_skill_from_archive` re-implemented the parent and
  dropped `app_config=self._app_config` from `_scan_skill_archive_contents_or_raise(...)`,
  so the content scan fell back to the process-global `get_app_config()` while the
  inherited archive preflight still read `self._app_config`. The two gates of one install
  could disagree about `skill_scan.enabled`.
- How to find the next one: grep for classes whose override re-implements a parent body
  (duplicated `ainstall_*` / `async def` bodies, no `super().`), then diff the argument
  lists against the parent. The tell is a **test asymmetry** — the parent has a kill-switch
  regression test, the override has none.

**Shape 2 — one side-effect owner, two handoff styles.** A cross-cutting side-effect is
applied by a *shared ingress path*; some implementations route through it and some
re-implement the work themselves, so only the routed ones get the side-effect.

- #5998: `ChannelManager._ingest_inbound_files` writes inbound attachments and then applies
  the sandbox read permit (`S_IRGRP | S_IROTH`) so a non-root sandbox can read the
  bind-mounted file. Telegram routes its bytes through the manager via
  `INBOUND_FILE_CONTENT_KEY` and inherits it; Feishu and DingTalk persist their own bytes and
  return a virtual path, bypassing both the write *and* the permit — so their attachments
  were silently unreadable in AIO/Docker sandbox mode.
- How to find the next one: find a side-effect performed in a shared ingress path, then grep
  for implementations that re-implement persistence instead of delegating. Cite provenance
  with `git log -S "<helper>" -- <file>` to show which sibling was already fixed.

Related, but **not** a security gate — keep them separate when writing the body: the
per-file LLM scan (`scan_skill_content`) reads `app_config` only for
`skill_evolution.moderation_model_name` and model construction. `skill_scan.enabled` does
not gate it.

## Fork-PR CI mechanics

- `license/cla` is a **cla-assistant GitHub App** run, **not** documented in
  `CONTRIBUTING.md` — grepping the docs for "CLA" wrongly suggests none is required. Read
  the PR's check runs instead. Unsigned, it is a silent indefinite stall that **only the
  account owner can clear** (their GitHub login, at
  `https://cla-assistant.io/bytedance/deer-flow?pullRequest=<N>`).
- Fork `pull_request` workflows land in `action_required` until a maintainer clicks
  "Approve and run workflows". A fork PR can therefore show only CLA + bot checks for a
  long time; that is **not** a failure. The maintainer's own branches run immediately.
  Consequence: run the suite locally before pushing — it is the only evidence until then.
- `backend-unit-tests (N)` failing on a fork PR is **often main-side drift, not you**.
  #5703 failed on `test_agent_guidance_check.py` (`backend/app/gateway/AGENTS.md` was 49155
  bytes against a 49152 budget), fixed on main by #5725 within the hour. Check
  `git log origin/main -- <the failing file>` before assuming your diff did it; merging
  `main` in is enough.
  - `normalized_utf8_size` normalizes CRLF→LF, so a CI number *larger* than your local
    `wc -c` means the file content genuinely differs — not a line-ending artifact.

## Reviewer style

Fast (~1.5 h), genuine, and specific. The reviewer re-runs the suite, reproduces the
red/green claim **in a clean worktree at the exact head SHA**, and confirms the cited files
at that ref. They then leave **one scoped inline follow-up** rather than a vague note, and
explicitly classify CI failures as yours or not-yours. Two consequences:

- They read the cited files at the head SHA, so if you push after their verification, say so.
- A follow-up request arrives as "worth adding while you're here" — implement it and bundle
  it into the same PR.

## Local environment caveats (author's macOS box)

- `cryptography`'s Rust binding fails to dlopen (`symbol not found in flat namespace
  '_EVP_DigestSqueeze'`). This breaks ~61 files under `backend/tests/` at **collection**,
  and many others fail at runtime on a transitive `cryptography` import. **A green local
  `make test` is unattainable — do not chase it.** Instead: run the targeted files, then run
  the same failing subset against pristine `origin/main` and compare counts. Identical
  counts = pre-existing.
- **Baseline technique:** run the pristine tree in a `git worktree` (`git worktree add
  --detach /tmp/base origin/main`), copy only the modified test file in, and diff the
  `^FAILED` lists with `comm`. Run its pytest with the main venv
  (`VIRTUAL_ENV=<main>/.venv <main>/.venv/bin/python -m pytest`) so `uv` does not try to
  sync a fresh environment. `git switch --detach origin/main` also works for a committed
  branch (the venv is gitignored, so it survives the switch).
- **cwd drift:** the Bash tool's cwd persists across calls. Always prefix
  `cd .../backend &&` — running `uv run pytest tests/` from the repo root silently runs the
  *root* `tests/` with a different python, not `backend/tests/`.
- **zsh does not word-split unquoted scalars.** `args=$(awk ...)` then `$args` passes one
  giant argument. Use a zsh array (`args+=(--flag=x)`), which expands per element.
- Redirecting a long pytest run to a file makes stdout block-buffered and looks hung. Use
  `-v` (line-buffered per test) to see progress.

## Landed examples

- **#5663** `fix(runtime): share one change position across an atomic thread operation` —
  merged ~2 days after opening. Full CI 14 pass / 4 skip / 0 fail.
- **#5703** `fix(skills): resolve the user-scoped install content scan from its own config` —
  two commits: the one-line fix (+ `TestInstallScanConfigParity`) and a second commit
  threading `app_config` into the per-file LLM scan (the reviewer's inline follow-up).
  Approved at `ae2dadd4` and merged **19 seconds later**.

The lane works end to end: self-found internal-invariant bug → doc-pinned contract →
red-then-green test → merge, both times in under two days. A follow-up commit pushed
*after* the reviewer verified an earlier SHA was accepted as-is — the reviewer had called
it "not blocking", and no split into a separate PR was needed.

**Merges here are squash merges.** Verify a landed PR with
`git log --oneline --grep="#<N>" origin/main` — a `git merge-base --is-ancestor <your-head>
origin/main` check returns NO even for a successful merge, because squash creates a new
commit. Do not conclude "not merged" from the ancestor check.
