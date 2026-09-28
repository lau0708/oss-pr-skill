# Auditing an AI-Agent project for contribution candidates

A survey checklist for generating *candidates* when hunting the self-found lane on an
agent/LLM framework. Adapted from a widely-circulated Chinese guide ("手把手教你为 AI
Agent 开源项目做贡献").

**Read this with the correction in mind.** That guide treats these seven dimensions as
"what the project is missing → propose it as a feature." Measured against deer-flow and
ArcReel, greenfield feature PRs from outside contributors land *poorly*: on ArcReel none
of the recent outside-contributor merges were self-invented features, and on deer-flow
only a minority of self-invented PRs are the feature kind. So use the dimensions to find
an **invariant violation, a parity gap, or a missing regression test** — not to pitch a
redesign. A dimension is a lead, not a proposal.

## The seven dimensions

For each, the useful question is: *does this project do the thing in two places, and do
the two disagree?* That is where a mergeable bug lives.

1. **Task planning** — ReAct / plan-and-execute / CoT / none. Is a plan persisted for
   resume? What happens to the plan when a subtask fails — replan, or abort?
   *Invariant lead:* the failure path usually skips a step the happy path performs.
2. **Multi-agent topology** — single agent or orchestrator+worker. How is state shared vs
   passed? Which agent owns which key?
   *Invariant lead:* two agents writing the same field, or a hand-off that drops context.
3. **Context management** — hard truncation / rolling window / summarization. What is
   lost on compression — tool-call history, intermediate results?
   *Invariant lead:* a summarizer that drops a field the reader still expects.
4. **Human-in-the-loop** — is there a pause/confirm path for risky operations (file write,
   outbound API, message send)? Checkpoint and resume?
   *Invariant lead:* the confirmation gate exists on one route but not its sibling.
5. **Evaluation** — any eval module or test set? Final-result-only or full trajectory?
   *Note:* "we have no eval pipeline" is a fine *observation* but a bad first PR — it is a
   greenfield subsystem. Use it to find what the existing tests *don't* pin instead.
6. **Tool retrieval & routing** — all tool schemas injected, or retrieved on demand? Is
   MCP supported? Are descriptions ambiguous enough to cause mis-selection?
   *Invariant lead:* two tool-loading paths that build the toolset differently.
7. **Streaming & intermediate-state visibility** — token streaming, event/state
   subscription for progress. Is a frame namespaced correctly for every consumer?
   *Invariant lead:* one consumer treats a namespaced frame as a root frame (this was a
   real deer-flow bug class).

## How to run the audit

- **Every finding must cite a file and a function.** A dimension with no file:line is not
  a finding, it is an impression. Discard it.
- Read the docs the repo ships (`AGENTS.md`, `docs/`, architecture notes) *first* — the
  invariant is often written down there, which is what makes a violation provable rather
  than a matter of taste. A doc-pinned contract plus a divergent implementation is the
  strongest possible candidate.
- Prefer the finding where **one implementation has a regression test and its sibling does
  not**. The test asymmetry is the fingerprint (see `SKILL.md` step 1).

## Candidate output format

| # | Dimension | File:function | Invariant violated | Impact | Blast radius | Competing PR? |
| --- | --- | --- | --- | --- | --- | --- |

Then rank by: (a) provable from a doc or a sibling implementation, (b) ≤ a few files,
(c) no existing test already covers it. Kill any row whose "competing PR?" column is not
empty — see `SKILL.md` step 1 on why that lane is a race.

## What the original guide adds that is worth keeping

- **Read before you opine:** README, CONTRIBUTING, CHANGELOG, the main entrypoint; then
  state the project's core agent loop and planning paradigm in 2–3 sentences. If you
  cannot, you have not read enough to propose anything.
- **Impact ratings** (high/medium/low) force you to rank instead of listing.
- **One-line "why this suits my stack"** per candidate — see `interview-narrative.md` for
  why this matters beyond vanity.
