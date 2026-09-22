---
name: model-routing
description: The cost model behind subagent dispatch — measured price and intelligence-index figures per tier (haiku 4.5, sonnet 5, opus 5.5, fable 5.1 at every effort level), the marginal-cost frontier, escalation rules, and Workflow tool tier mappings. Use when deciding which agent tier (grunt/scout/chore/dev/critic/sage/oracle) a task belongs to, when choosing a model or effort for any Agent or Workflow call, when justifying an escalation past dev, when asked whether fable or sonnet is ever worth it, when adding or retiring a tier, or when prices and index scores change and the ladder needs recomputing.
---

# Model routing — the cost model

The one-page dispatch policy is injected every session by this plugin's
SessionStart hook. This skill is the reasoning underneath it: load it when you
need to justify a tier choice, defend an escalation, or update the table.

Machine-readable source of truth: `model-routing.json` at this plugin's root.

## Measured points

Everything measured, sorted by price. Index is the Artificial Analysis
Intelligence Index (the 2026-09 revision — scores are not comparable with
earlier versions of this table). Price is USD per reference task-run, measured
locally — recompute rather than trusting these if either moves.

| point | model / effort | $ | index | index/$ | × haiku | status |
|---|---|---|---|---|---|---|
| haiku-4.5 | haiku, low | 0.21 | 17 | 81.0 | 1.00 | **rung** — `grunt`, `scout` |
| sonnet-low | sonnet, low | 0.51 | 24 | 47.1 | 2.43 | off hull (opus-low: +18 for $0.04) |
| opus-low | opus, low | 0.55 | 42 | 76.4 | 2.62 | **rung** — `chore` |
| sonnet-med | sonnet, medium | 1.00 | 28 | 28.0 | 4.76 | dominated by opus-low |
| opus-med | opus, medium | 1.34 | 51 | 38.1 | 6.38 | **rung** — `dev` |
| sonnet-high | sonnet, high | 1.79 | 32 | 17.9 | 8.52 | dominated by opus-low |
| opus-high | opus, high | 1.82 | 54 | 29.7 | 8.67 | **rung** — `critic` (default thinker), main loop |
| fable-low | fable, low | 2.37 | 47 | 19.8 | 11.29 | dominated by opus-med |
| sonnet-xhigh | sonnet, xhigh | 2.87 | 34 | 11.8 | 13.67 | dominated by opus-low |
| fable-med | fable, medium | 2.98 | 49 | 16.4 | 14.19 | dominated by opus-med |
| opus-xhigh | opus, xhigh | 3.46 | 56 | 16.2 | 16.48 | **rung** — `sage` |
| fable-high | fable, high | 3.91 | 51 | 13.0 | 18.62 | dominated by opus-med |
| sonnet-max | sonnet, max | 5.00 | 38 | 7.6 | 23.81 | dominated by opus-low |
| opus-max | opus, max | 5.98 | 58 | 9.7 | 28.48 | **rung** — `oracle` (ceiling) |
| fable-xhigh | fable, xhigh | 5.98 | 53 | 8.9 | 28.48 | dominated by opus-high |
| fable-max | fable, max | 7.63 | 53 | 6.9 | 36.33 | dominated by opus-high |

## How the rungs were chosen

Walk the lower-left convex hull: from each rung, take the next point that buys
index points cheapest per dollar. Anything not on that walk is skipped.

**The hull is haiku, then Opus 5.5 at every effort.** haiku → opus-low →
opus-med → opus-high → opus-xhigh → opus-max. Nothing else is on it.

**Fable 5.1 is dominated at every effort.** Each fable point has an opus point
that is cheaper *and* scores at least as high: fable-high ($3.91 / 51) ties
opus-med ($1.34 / 51) at a third of the price; fable-xhigh and fable-max
($5.98 and $7.63 / 53) both lose to opus-high ($1.82 / 54). Up to 1.2.x the
think tiers ran on fable; 2.0.0 moves all of them to opus.

**Sonnet 5 is dominated at every effort but low**, and sonnet-low is off the
hull by a wide margin: opus-low costs $0.04 more and scores 18 points higher.
Never pick it.

**`judge` is retired.** In 1.2.x it sat on opus-xhigh between fable-high
(`sage`) and fable-xhigh (`oracle`). With the think side on opus there is no
point left between `sage` (opus-xhigh) and `oracle` (opus-max), so the think
side has three rungs: `critic`, `sage`, `oracle`.

**Step ratios are wider than before.** haiku → opus-low is 2.62× and
opus-low → opus-med 2.44×; the think side steps 1.36×, 1.90×, 1.73×. The old
"no step above 1.5×" property is gone — there are no hull points to fill the
gaps, and the dominated points that sit in them are worse, not cheaper.

## The cliff

Marginal cost per index point along the ladder:

| step | Δ$ | Δindex | $/point |
|---|---|---|---|
| haiku → opus-low | 0.34 | 25 | 0.0136 |
| opus-low → opus-med | 0.79 | 9 | 0.0878 |
| opus-med → opus-high | 0.48 | 3 | 0.1600 |
| opus-high → opus-xhigh | 1.64 | 2 | **0.8200** |
| opus-xhigh → opus-max | 2.52 | 2 | 1.2600 |

Reaching `critic` is cheap. The first step past it is 5.1× more expensive per
point, and the last one 7.9×. Cumulative over `dev`: `critic` +$0.48, `sage`
+$2.12, `oracle` +$4.64. The cliff moved: it used to sit between `dev` and the
first thinker; it now sits between `critic` and `sage`. That lines up exactly
with the autonomous ceiling — every rung an agent may pick on its own is below
the cliff, every rung above it needs the user.

Below the cliff, guessing high costs pennies. Above it, guessing high is the
dominant way to waste money, and the waste is per call: `sage` where `critic`
would do wastes $1.64; `oracle` where `sage` would do wastes $2.52.

## The autonomous ceiling

`dev` for code, `critic` for judgement. `sage` and `oracle` are **user-named
tiers**: the agent never dispatches them on its own, no matter how hard or
consequential the task looks. When `critic` or `dev` has failed twice, the
correct move is to stop and report — what failed, which tier you would escalate
to, and what it costs — and let the user decide whether to pay. A grant in the
user's current message ("use sage", "escalate if needed", "go up to oracle") is
what unlocks the rung.

## Assigning a tier

Ask in order, stop at the first yes:

1. Is the answer already in the repo or in a command's output? → `grunt`, or
   `scout` if the search pattern isn't known yet
2. Is it code whose shape is already decided? → `chore`
3. Is it code whose correctness needs reasoning while writing? → `dev`
4. Is it a decision or judgement, producing no code? → `critic`
5. Does it carry auth/money/migration/concurrency invariants, move an
   architectural boundary, or has `critic` failed once? → ask for `sage`
6. Is it irreversible, or has `sage` already failed? → ask for `oracle`

Steps 5–6 are requests to the user, not dispatches.

The common misroute is treating *consequential* as *difficult*. A production
config change can be mechanical; route it to `chore` and verify carefully.
Difficulty is about the reasoning the task requires, not about what it touches.

The second common misroute is picking by model name. Fable and sonnet lose to
opus at every effort on this table. The (model, effort) pair is the tier, and
right now every rung above haiku is opus.

## Escalation

Escalate on **observed failure only** — a wrong result, a failed verification,
a hedge, or a question the agent was meant to answer. Never on anticipated
difficulty.

- One rung at a time for difficulty. Stakes may skip: an auth diff goes
  straight to `sage`, an irreversible call straight to `oracle`. "This is
  hard" never skips.
- Always pass the failed attempt down as context. The higher tier restarting
  from zero is how you pay twice for the same work.
- Two failures at one rung means escalate, not retry a third time.
- Past `critic`, escalation is a question to the user, not an action. Report
  the failed attempt and the proposed tier with its cost, then wait.
- There is no rung above `oracle`. If `oracle` fails, the problem is the
  premise, not the model; go back and check what every tier assumed.

Escalating past `dev` needs a stated reason. "This seems hard" is not one;
"`dev` produced a fix that failed its own test twice" is — and even then, past
`critic` the reason is presented to the user rather than acted on.

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
agent(p, {agentType: 'critic', model: 'opus',  effort: 'high'})    // verify (default)
agent(p, {agentType: 'sage',   model: 'opus',  effort: 'xhigh'})   // verify, hard / adversarial
agent(p, {agentType: 'oracle', model: 'opus',  effort: 'max'})     // final judgement, irreversible
```

Fan-out stages take the cheap tiers; a verify fan-out runs on `critic`, and
only the converging stage pays for `sage` or above. A fan-out of twenty `sage`
calls costs more than the decision it informs is worth — that shape is the
mistake this table exists to prevent.

## Updating the table

When prices or index scores change, edit `model-routing.json` first, then
recompute index/$ and the marginal column before touching prose. Check three
things: whether any point has become dominated (as all of sonnet and fable
are now), whether the hull walk still lands on the same rungs, and whether the
cliff has moved. The cliff's location determines where "escalate freely" turns
into "escalate only on evidence", so the ladder's shape follows from it.
