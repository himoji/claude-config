---
name: model-routing
description: The cost model behind subagent dispatch — measured price and intelligence-index figures per tier (haiku 4.5, opus, fable 5.1 at every effort level), the marginal-cost frontier, escalation rules, and Workflow tool tier mappings. Use when deciding which agent tier (grunt/scout/chore/dev/sage/oracle) a task belongs to, when choosing a model or effort for any Agent or Workflow call, when justifying an escalation past dev, when asked whether fable/max is worth it, when adding or retiring a tier, or when prices and index scores change and the ladder needs recomputing.
---

# Model routing — the cost model

The one-page dispatch policy is injected every session by this plugin's
SessionStart hook. This skill is the reasoning underneath it: load it when you
need to justify a tier choice, defend an escalation, or update the table.

Machine-readable source of truth: `model-routing.json` at this plugin's root.

## Measured points

Everything measured, sorted by price. Index is the Artificial Analysis
Intelligence Index. Price is USD per reference task-run, measured locally —
recompute rather than trusting these if either moves.

| point | model / effort | $ | index | index/$ | × haiku | status |
|---|---|---|---|---|---|---|
| haiku-4.5 | haiku, low | 0.22 | 30 | 136.4 | 1.00 | **rung** — `grunt`, `scout` |
| sonnet-5 | sonnet, medium | 0.42 | 43 | 102.4 | 1.91 | dominated by opus-low |
| opus-low | opus, low | 0.43 | 52 | 120.9 | 1.95 | **rung** — `chore` |
| opus-med | opus, medium | 0.72 | 59 | 81.9 | 3.27 | **rung** — `dev` |
| fable-low | fable, low | 0.77 | 58 | 75.3 | 3.50 | dominated by opus-med |
| fable-med | fable, medium | 1.00 | 60 | 60.0 | 4.55 | off hull |
| opus-high | opus, high | 1.23 | 61 | 49.6 | 5.59 | off hull (old `sage`) |
| fable-high | fable, high | 1.43 | 62 | 43.4 | 6.50 | **rung** — `sage`, main loop |
| opus-xhigh | opus, xhigh | 1.80 | 63 | 35.0 | 8.18 | on hull, +1 only; no agent |
| fable-xhigh | fable, xhigh | 2.65 | 65 | 24.5 | 12.05 | **rung** — `oracle` |
| fable-max | fable, max | 3.69 | 66 | 17.9 | 16.77 | ceiling; user-named only |

## How the rungs were chosen

Walk the lower-left convex hull: from each rung, take the next point that buys
index points cheapest per dollar. Anything not on that walk is skipped — not
because it is bad, but because a neighbour buys the same points for less.

**Two points are strictly dominated** and appear nowhere in the ladder:

- **sonnet-5** — $0.42 for 43, against opus-low at $0.43 for 52. One cent
  more buys nine points.
- **fable-low** — $0.77 for 58, against opus-med at $0.72 for 59. Five cents
  *less* buys one point more. Fable at low effort is never the right pick.

**Three points are off the hull.** From opus-med, fable-med buys +1 for $0.28
and opus-high buys +2 for $0.51 ($0.255/pt); fable-high buys +3 for $0.71
($0.237/pt), cheaper per point than either and above both. So `sage` moved
from opus-high to fable-high. opus-xhigh is technically on the hull (+1 over
fable-high for $0.37) but a peak rung that clears `sage` by a single point is
not worth an agent; `oracle` takes fable-xhigh, +3 over `sage`.

**fable-max is a ceiling, not a rung.** $1.04 for one index point is the worst
step on the board — 2.5× the per-point price of the `oracle` step. No agent
pins it. It is used only when the user asks for `max` by name.

## The cliff

Marginal cost per index point along the ladder:

| step | Δ$ | Δindex | $/point |
|---|---|---|---|
| haiku → opus-low | 0.21 | 22 | 0.0095 |
| opus-low → opus-med | 0.29 | 7 | 0.0414 |
| opus-med → fable-high | 0.71 | 3 | **0.2367** |
| fable-high → fable-xhigh | 1.22 | 3 | 0.4067 |
| fable-xhigh → fable-max | 1.04 | 1 | 1.0400 |

Reaching `dev` is cheap. Going past it is 5.7× more expensive per point, and
`sage` + `oracle` together buy six index points for $1.93 over `dev`. That
asymmetry is the entire argument for failure-triggered escalation: below the
cliff, guessing high costs pennies; above it, guessing high is the dominant way
to waste money.

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

The second common misroute is "it's fable, so it must be better". Fable at low
effort loses to opus at medium on both axes. Model name is not a tier; the
(model, effort) pair is.

## Escalation

Escalate on **observed failure only** — a wrong result, a failed verification,
a hedge, or a question the agent was meant to answer. Never on anticipated
difficulty.

- One rung at a time. Skipping rungs throws away the cheap tier's findings.
- Always pass the failed attempt down as context. The higher tier restarting
  from zero is how you pay twice for the same work.
- Two failures at one rung means escalate, not retry a third time.
- There is no rung above `oracle`. If `oracle` fails, the problem is the
  premise, not the model; go back and check what every tier assumed.

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
agent(p, {agentType: 'sage',   model: 'fable', effort: 'high'})    // verify
agent(p, {agentType: 'oracle', model: 'fable', effort: 'xhigh'})   // judge
```

Fan-out stages take the cheap tiers; only the converging stage pays for `sage`.
A fan-out of twenty `sage` calls costs more than the decision it informs is
worth — that shape is the mistake this table exists to prevent.

## Updating the table

When prices or index scores change, edit `model-routing.json` first, then
recompute index/$ and the marginal column before touching prose. Check three
things: whether any point has become dominated (as sonnet-5 and fable-low
are), whether the hull walk still lands on the same rungs, and whether the
cliff has moved. The cliff's location determines where "escalate freely" turns
into "escalate only on evidence", so the ladder's shape follows from it.
