# Model routing

Pick the cheapest tier that can do the job, then stop. Full table and rationale: the `model-routing` skill.

## The ladder

| agent | model / effort | cost | use for |
|---|---|---|---|
| `grunt` | haiku, low | 1.0× | **stupid work** — run it and report, find the files, list the versions. No judgement. |
| `scout` | haiku, medium | 1.0× | **stupid work, open-ended** — "where is X handled", "how is this wired". Search, no decisions. |
| `chore` | opus, low | 2.6× | **dumb code** — decided renames/codemods, boilerplate, scaffolding, specified tests. Typing, not deciding. |
| `dev` | opus, medium | 6.4× | **smart code** — features, unknown-cause debugging, refactors across invariants, auth/money/migrations/concurrency. |
| `critic` | opus, high | 8.7× | **think, everyday** — ordinary diff review, verify one claim, synthesize a few reports, design questions with an existing pattern. Read-only. **Default thinker.** |
| `sage` | opus, xhigh | 16.5× | **think, hard** — architecture, diffs carrying auth/money/migration/concurrency invariants, adversarial verification, or `critic` failed once. Read-only. |
| `oracle` | opus, max | 28.5× | **peak** — irreversible calls, or `sage` failed. Rare by design. |

Multipliers are vs. haiku on measured cost. Every rung above haiku is Opus 5.5: on the current index, every Fable 5.1 and Sonnet 5 point is beaten by an opus point that is cheaper and scores at least as high.

**Autonomous ceiling: `dev` for code, `critic` for judgement.** `sage` and `oracle` are dispatched only when the user asks for them in the current message (by name, or by explicitly allowing escalation). Never on your own judgement, however hard or important the task looks.

## Rules

0. **Do not get expensive unless asked.** Nothing above `critic` is dispatched autonomously. If `critic` (or `dev`) has failed twice, stop and report: what failed, what you'd escalate to, what it costs. The user decides whether to pay for `sage`/`oracle`.
1. **Never sonnet, never fable — at any effort.** opus-low beats sonnet-low by 18 index points for $0.04 more; fable-high costs 3× opus-med for the same score. Model name is not a tier — the (model, effort) pair is.
2. **`grunt` is the default subagent, `critic` is the default thinker.** `sage`/`oracle` are reached only by the user asking — failure and stakes are reasons to *ask*, not to escalate.
3. **`dev` is the ceiling for writing code.** The three think tiers decide and judge; they don't hold the keyboard.
4. **Escalate on observed failure, never in anticipation.** One rung at a time, passing the failed attempt down as context. Two failures at a rung means escalate, not retry — and past `critic`, escalating means asking the user first.
5. **One thinker, many limbs.** The main loop is the think tier; it should be dispatching cheap subagents, not doing lookups itself. Every `Grep` a high-effort agent runs personally is billed at its own rate.
6. **Effort is per-agent and overrides the global `effortLevel`.** A `grunt` in an xhigh session still runs cheap — that's the whole mechanism.

## Where the money goes

Climbing to `critic` is cheap: at most **$0.16 per index point** (`dev` → `critic`). The next step, `critic` → `sage`, costs **$0.82/point** — 5.1× worse — and `sage` → `oracle` $1.26/point. The cliff sits exactly on the autonomous ceiling.

In absolute terms: `critic` is +$0.48 over `dev`; `sage` +$2.12; `oracle` +$4.64. Picking `sage` where `critic` would do wastes $1.64 per call; picking `oracle` where `sage` would do wastes $2.52.

So: fan out wide and cheap, converge narrow and expensive. Many grunts, a few critics, rarely a sage, at most one oracle.

## Deciding which tier

Ask, in order:

1. Is the answer already sitting in the repo or in a command's output? → `grunt` / `scout`
2. Is it code, and is the shape already decided? → `chore`
3. Is it code, and does writing it require reasoning about correctness? → `dev`
4. Is it a decision or a judgement, with no code produced? → `critic`
5. Does that judgement cover auth/money/migrations/concurrency, redraw an architectural boundary, or has `critic` already failed once? → **ask the user** for `sage`
6. Is it irreversible, or has `sage` already failed? → **ask the user** for `oracle`

Steps 5–6 never dispatch on their own. The user's message must name the tier or grant the escalation.

Sounding important is not a reason to escalate. A cheaper attempt actually failing is.

## Workflow tool

Same tiers via `agent(prompt, {agentType, model, effort})`:

```js
agent(p, {agentType: 'scout',  model: 'haiku', effort: 'medium'})  // discover
agent(p, {agentType: 'chore',  model: 'opus',  effort: 'low'})     // mechanical
agent(p, {agentType: 'dev',    model: 'opus',  effort: 'medium'})  // implement
agent(p, {agentType: 'critic', model: 'opus',  effort: 'high'})    // verify (default)
agent(p, {agentType: 'sage',   model: 'opus',  effort: 'xhigh'})   // verify, hard / adversarial
agent(p, {agentType: 'oracle', model: 'opus',  effort: 'max'})     // final judgement, irreversible
```

Fan-out stages take the cheap tiers. Verification fans out on `critic`; the converging stage pays for `sage` or above only when the user asked for it.
