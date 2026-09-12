# Model routing

Pick the cheapest tier that can do the job, then stop. Full table and rationale: the `model-routing` skill.

## The ladder

| agent | model / effort | cost | use for |
|---|---|---|---|
| `grunt` | haiku, low | 1.0× | **stupid work** — run it and report, find the files, list the versions. No judgement. |
| `scout` | haiku, medium | 1.0× | **stupid work, open-ended** — "where is X handled", "how is this wired". Search, no decisions. |
| `chore` | opus, low | 1.9× | **dumb code** — decided renames/codemods, boilerplate, scaffolding, specified tests. Typing, not deciding. |
| `dev` | opus, medium | 3.3× | **smart code** — features, unknown-cause debugging, refactors across invariants, auth/money/migrations/concurrency. |
| `critic` | fable, medium | 4.5× | **think, everyday** — ordinary diff review, verify one claim, synthesize a few reports, design questions with an existing pattern. Read-only. **Default thinker.** |
| `sage` | fable, high | 6.5× | **think, hard** — architecture, diffs carrying auth/money/migration/concurrency invariants, adversarial verification, or `critic` failed once. Read-only. |
| `judge` | opus, xhigh | 8.2× | **peak, recoverable** — irreversible-but-undoable calls (backup, flag, rollback exists), or `dev`+`sage` both failed. Read-only. |
| `oracle` | fable, xhigh | 12.0× | **peak, unrecoverable** — no rollback path, or `judge` failed. Rare by design. |

Multipliers are vs. haiku on measured cost. No step on the ladder is more than 1.5× the one below it.

**Autonomous ceiling: `dev` for code, `critic` for judgement.** `sage`, `judge`, `oracle` and `fable, max` are dispatched only when the user asks for them in the current message (by name, or by explicitly allowing escalation). Never on your own judgement, however hard or important the task looks.

## Rules

0. **Do not get expensive unless asked.** Nothing above `critic` is dispatched autonomously. If `critic` (or `dev`) has failed twice, stop and report: what failed, what you'd escalate to, what it costs. The user decides whether to pay for `sage`/`judge`/`oracle`.
1. **Never sonnet-5, never fable-low.** Each is strictly dominated: opus-low beats sonnet-5 for $0.01 more; opus-med beats fable-low for $0.05 *less*. Model name is not a tier — the (model, effort) pair is.
2. **`grunt` is the default subagent, `critic` is the default thinker.** `sage`/`judge`/`oracle` are reached only by the user asking — failure and stakes are reasons to *ask*, not to escalate.
3. **`dev` is the ceiling for writing code.** The four think tiers decide and judge; they don't hold the keyboard.
4. **Escalate on observed failure, never in anticipation.** One rung at a time, passing the failed attempt down as context. Two failures at a rung means escalate, not retry — and past `critic`, escalating means asking the user first.
5. **One thinker, many limbs.** The main loop is the think tier; it should be dispatching cheap subagents, not doing lookups itself. Every `Grep` a high-effort agent runs personally is billed at its own rate.
6. **Effort is per-agent and overrides the global `effortLevel`.** A `grunt` in an xhigh session still runs cheap — that's the whole mechanism.

## Where the money goes

Climbing to `dev` is cheap: **$0.041 per index point**. The first step past it, `dev` → `critic`, costs **$0.28/point** — 6.8× worse — and every step above stays in that band ($0.22–0.43/pt). The last point, `oracle` → `max`, costs $1.04 on its own.

In absolute terms: `critic` is +$0.28 over `dev`; `sage` +$0.71; `judge` +$1.08; `oracle` +$1.93. Picking `sage` where `critic` would do wastes $0.43 per call; picking `oracle` where `judge` would do wastes $0.85.

So: fan out wide and cheap, converge narrow and expensive. Many grunts, a few critics, rarely a sage, at most one judge or oracle.

## Deciding which tier

Ask, in order:

1. Is the answer already sitting in the repo or in a command's output? → `grunt` / `scout`
2. Is it code, and is the shape already decided? → `chore`
3. Is it code, and does writing it require reasoning about correctness? → `dev`
4. Is it a decision or a judgement, with no code produced? → `critic`
5. Does that judgement cover auth/money/migrations/concurrency, redraw an architectural boundary, or has `critic` already failed once? → **ask the user** for `sage`
6. Is it irreversible, or has a cheaper tier already failed twice? → **ask the user** for `judge` (rollback/backup/flag exists) or `oracle` (nothing can undo it, or `judge` failed)

Steps 5–6 never dispatch on their own. The user's message must name the tier or grant the escalation.

Sounding important is not a reason to escalate. A cheaper attempt actually failing is.

## Workflow tool

Same tiers via `agent(prompt, {agentType, model, effort})`:

```js
agent(p, {agentType: 'scout',  model: 'haiku', effort: 'medium'})  // discover
agent(p, {agentType: 'chore',  model: 'opus',  effort: 'low'})     // mechanical
agent(p, {agentType: 'dev',    model: 'opus',  effort: 'medium'})  // implement
agent(p, {agentType: 'critic', model: 'fable', effort: 'medium'})  // verify (default)
agent(p, {agentType: 'sage',   model: 'fable', effort: 'high'})    // verify, hard / adversarial
agent(p, {agentType: 'judge',  model: 'opus',  effort: 'xhigh'})   // final judgement
agent(p, {agentType: 'oracle', model: 'fable', effort: 'xhigh'})   // final judgement, unrecoverable stakes
```

Fan-out stages take the cheap tiers. Verification fans out on `critic`; the converging stage pays for `sage` or above only when the user asked for it.
