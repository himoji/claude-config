---
name: model-routing
description: The cost model behind subagent dispatch — measured price and intelligence-index figures per tier, the marginal-cost frontier, escalation rules, and Workflow tool tier mappings. Use when deciding which agent tier a task belongs to, when justifying an escalation past dev, when adding or retiring a tier, or when prices and index scores change and the ladder needs recomputing.
---

# Model routing — the cost model

The one-page dispatch policy is injected every session by this plugin's
SessionStart hook. This skill is the reasoning underneath it: load it when you
need to justify a tier choice, defend an escalation, or update the table.

Machine-readable source of truth: `model-routing.json` at this plugin's root.

## Measured frontier

| tier | model / effort | $ | index | index/$ | × haiku |
|---|---|---|---|---|---|
| haiku-4.5 | haiku, low | 0.22 | 30 | 136.4 | 1.00 |
| opus-low | opus, low | 0.43 | 52 | 120.9 | 1.95 |
| opus-med | opus, medium | 0.72 | 59 | 81.9 | 3.27 |
| opus-high | opus, high | 1.23 | 61 | 49.6 | 5.59 |
| opus-xhigh | opus, xhigh | 1.80 | 63 | 35.0 | 8.18 |

Index is the Artificial Analysis Intelligence Index. Price is USD per reference
task-run, measured locally — recompute rather than trusting these if either
moves.

## Two results that drive every rule

**sonnet-5 is strictly dominated.** $0.42 for index 43, against opus-low at
$0.43 for index 52. One cent more buys nine index points. There is no task on
which sonnet-5 is the correct pick, so it appears nowhere in the ladder.

**The cliff is opus-med → opus-high.** Marginal cost per index point along the
frontier:

| step | Δ$ | Δindex | $/point |
|---|---|---|---|
| haiku → opus-low | 0.21 | 22 | 0.0095 |
| opus-low → opus-med | 0.29 | 7 | 0.0414 |
| opus-med → opus-high | 0.51 | 2 | **0.2550** |
| opus-high → opus-xhigh | 0.57 | 2 | 0.2850 |

Reaching `dev` is cheap. Going past it is 6.2× more expensive per point, and
`sage` + `oracle` together buy four index points for $1.08. That asymmetry is
the entire argument for failure-triggered escalation: below the cliff, guessing
high costs pennies; above it, guessing high is the dominant way to waste money.

## Assigning a tier

Ask in order, stop at the first yes:

1. Is the answer already in the repo or in a command's output? → `grunt`, or
   `scout` if the search pattern isn't known yet
2. Is it code whose shape is already decided? → `chore`
3. Is it code whose correctness needs reasoning while writing? → `dev`
4. Is it a decision or judgement, producing no code? → `sage`
5. Is it irreversible, or has a cheaper tier already failed twice? → `oracle`

The common misroute is treating *consequential* as *difficult*. A production
config change can be mechanical; route it to `chore` and verify carefully.
Difficulty is about the reasoning the task requires, not about what it touches.

## Escalation

Escalate on **observed failure only** — a wrong result, a failed verification,
a hedge, or a question the agent was meant to answer. Never on anticipated
difficulty.

- One rung at a time. Skipping rungs throws away the cheap tier's findings.
- Always pass the failed attempt down as context. The higher tier restarting
  from zero is how you pay twice for the same work.
- Two failures at one rung means escalate, not retry a third time.

Escalating past `dev` needs a stated reason. "This seems hard" is not one;
"`dev` produced a fix that failed its own test twice" is.

## De-escalation

Routing is not one-way. When a task turns out smaller than dispatched — the
architecture question was really "where is this configured" — say so and
re-dispatch downward rather than finishing at the expensive tier because it is
already loaded.

## Workflow tool

```js
agent(p, {agentType: 'scout',  model: 'haiku', effort: 'medium'})  // discover
agent(p, {agentType: 'chore',  model: 'opus',  effort: 'low'})     // mechanical
agent(p, {agentType: 'dev',    model: 'opus',  effort: 'medium'})  // implement
agent(p, {agentType: 'sage',   model: 'opus',  effort: 'high'})    // verify
agent(p, {agentType: 'oracle', model: 'opus',  effort: 'xhigh'})   // judge
```

Fan-out stages take the cheap tiers; only the converging stage pays for `sage`.
A fan-out of twenty `sage` calls costs more than the decision it informs is
worth — that shape is the mistake this table exists to prevent.

## Updating the table

When prices or index scores change, edit `model-routing.json` first, then
recompute index/$ and the marginal column before touching prose. Check two
things: whether any tier has become dominated (as sonnet-5 is), and whether the
cliff has moved. The cliff's location determines where "escalate freely" turns
into "escalate only on evidence", so the ladder's shape follows from it.
