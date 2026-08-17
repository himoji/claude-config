# Model routing

Pick the cheapest tier that can do the job, then stop. Full table and rationale: `~/.claude/model-routing.json`.

## The ladder

| agent | model / effort | cost | use for |
|---|---|---|---|
| `grunt` | haiku, low | 1.0× | **stupid work** — run it and report, find the files, list the versions. No judgement. |
| `scout` | haiku, medium | 1.0× | **stupid work, open-ended** — "where is X handled", "how is this wired". Search, no decisions. |
| `chore` | opus, low | 1.9× | **dumb code** — decided renames/codemods, boilerplate, scaffolding, specified tests. Typing, not deciding. |
| `dev` | opus, medium | 3.3× | **smart code** — features, unknown-cause debugging, refactors across invariants, auth/money/migrations/concurrency. |
| `sage` | opus, high | 5.6× | **think** — architecture, hard review, adversarial verification, final synthesis. Read-only. |
| `oracle` | opus, xhigh | 8.2× | **peak** — irreversible calls, or after `dev`+`sage` have both failed. Rare by design. |

Multipliers are vs. haiku on measured cost.

## Rules

1. **Never sonnet-5.** opus-low costs $0.01 more (+2%) and scores 9 index points higher (+21%). It is strictly dominated — there is no task where it is the right pick.
2. **`grunt` is the default subagent.** Dispatch there unless the task requires deciding something. Let failure pull the tier upward.
3. **`dev` is the ceiling for writing code.** `sage` and `oracle` decide and judge; they don't hold the keyboard.
4. **Escalate on observed failure, never in anticipation.** One rung at a time, passing the failed attempt down as context. Two failures at a rung means escalate, not retry.
5. **One thinker, many limbs.** The main loop is the think tier; it should be dispatching cheap subagents, not doing lookups itself. Every `Grep` a high-effort agent runs personally is billed at its own rate.
6. **Effort is per-agent and overrides the global `effortLevel`.** A `grunt` in an xhigh session still runs cheap — that's the whole mechanism.

## Where the money goes

Climbing to `dev` is cheap: **$0.041 per index point**. Climbing past it costs **$0.255/point** — 6.2× worse. `sage` and `oracle` together buy 4 index points for +$1.08.

So: fan out wide and cheap, converge narrow and expensive. Many grunts, few sages, at most one oracle.

## Deciding which tier

Ask, in order:

1. Is the answer already sitting in the repo or in a command's output? → `grunt` / `scout`
2. Is it code, and is the shape already decided? → `chore`
3. Is it code, and does writing it require reasoning about correctness? → `dev`
4. Is it a decision or a judgement, with no code produced? → `sage`
5. Is it irreversible, or has a cheaper tier already failed twice? → `oracle`

Sounding important is not a reason to escalate. A cheaper attempt actually failing is.

## Workflow tool

Same tiers via `agent(prompt, {agentType, model, effort})`:

```js
agent(p, {agentType: 'scout',  model: 'haiku', effort: 'medium'})  // discover
agent(p, {agentType: 'chore',  model: 'opus',  effort: 'low'})     // mechanical
agent(p, {agentType: 'dev',    model: 'opus',  effort: 'medium'})  // implement
agent(p, {agentType: 'sage',   model: 'opus',  effort: 'high'})    // verify
agent(p, {agentType: 'oracle', model: 'opus',  effort: 'xhigh'})   // final judgement
```

Fan-out stages take the cheap tiers. Only the converging stage pays for `sage`.
