# The interview narrative

A merged PR is the artifact; the narrative is the product. The user's stated goal is a PR
they can *defend* in an interview — decisions, tradeoffs, dead ends — not just a green
check mark.

**Capture it as you go, not afterwards.** A narrative reconstructed from memory a month
later is generic; one assembled while the evidence is in front of you is specific. Keep a
running note per PR with the four things below, and update it at each transition.

## Four things to collect during the work

1. **The invariant, in one sentence.** "Two gates of one install resolved
   `skill_scan.enabled` from different config objects." If you cannot state it without
   saying "the code," you do not own the change yet.
2. **The decisions you made and the alternatives you rejected.** This is what interviewers
   probe. Record the rejected option *and why*: "fixed it in the override rather than
   refactoring the shared base, because the base is used by the public path and the
   divergence was only reachable via the override."
3. **The obstacles and how you got out.** Include the ones that cost real time: the
   local `cryptography` dlopen failure, the cwd drift, the CI failure that turned out to
   be main-side drift. A narrated dead end is worth more than a narrated success.
4. **Evidence, quoted verbatim.** The red assertion text; the `file:line` of the
   divergent call site; CI counts; **direct quotes from the maintainer's review**. A
   reviewer independently reproducing your red/green is a third-party validation you
   cannot manufacture — quote the sentence.

## The seven-part structure

| Part | Content |
| --- | --- |
| **Context** | What the project is, the problem it solves in the agent space, why you picked it, what was missing. |
| **Contribution** | One sentence: what you implemented/improved/introduced, where it sits, which paths it affects. |
| **Process** | 3–5 steps focused on *decisions*, not code. "I chose B over A because…" |
| **Result** | PR status + link; behavioural impact; any quantified metric; maintainer feedback quoted. |
| **Challenges** | 1–2 real blockers: what it was → how you diagnosed it → how it resolved. |
| **Reflection** | What you would do differently: technical, process, scope. |
| **Abilities** | 2–3 capabilities this demonstrates, mapped to what interviewers test. |

## Worked example (deer-flow, both merged)

- **Context** — LangGraph super-agent, Python backend + Next.js. Its stores have two
  backends (SQL vs memory) that must behave identically; only one backend typically gets
  the regression test.
- **Contribution** — two one-to-few-line fixes closing invariant violations where an
  override/back-end diverged from its documented contract.
- **Process** — read the doc-pinned contract → diff the sibling implementation → find the
  test asymmetry → write the red test with a control assertion → minimal fix → baseline-
  compare the environment-broken suite against pristine `main`.
- **Result** — both merged, each under two days; the reviewer independently reproduced the
  red/green in a clean worktree at the exact head SHA.
- **Challenges** — a CI failure that looked like mine was 3 bytes of main-side drift in an
  unrelated `AGENTS.md` budget (already fixed upstream); proven by `git log origin/main --
  <file>`, not guessed.
- **Reflection** — the follow-up commit pushed after the reviewer verified an earlier SHA
  was fine to bundle, but I should have flagged the head move in the same breath as the
  push rather than in a separate reply.
- **Abilities** — reading an unfamiliar codebase against its own docs; isolating a
  reachable-from-production bug from a merely-different one; separating "I broke it" from
  "it was already broken" with evidence.

## Anti-patterns

- "I added a feature and it got merged." — no decision, no tradeoff, nothing to probe.
- Listing files changed instead of decisions made.
- Claiming an impact you did not measure. If you have no number, say what changed
  behaviourally instead of inventing a percentage.
