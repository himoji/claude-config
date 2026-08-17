# claude-config

Portable Claude Code config: cost-tiered subagents plus the routing policy that
picks between them.

## Install on a new machine

```bash
git clone <remote> ~/Documents/git/claude-config
~/Documents/git/claude-config/install.sh
```

Symlinks into `~/.claude`. Idempotent, and any real file it displaces is copied
to `*.pre-link` first. Agent definitions load at session start, so open a new
session afterwards.

Then merge `settings.reference.json` into `~/.claude/settings.json` by hand —
hooks and plugin marketplace entries carry absolute paths and don't travel.

## What's here

| path | scope |
|---|---|
| `agents/*.md` | six subagents, each pinning its own model + reasoning effort |
| `model-routing.md` | the dispatch policy, imported by `~/.claude/CLAUDE.md` |
| `model-routing.json` | prices, cost frontier, escalation rules, workflow defaults |
| `settings.reference.json` | portable subset of settings.json — manual merge |
| `RTK.md` | rtk proxy notes |

## The ladder

| agent | model / effort | cost | for |
|---|---|---|---|
| `grunt` | haiku, low | 1.0× | run it and report; no judgement |
| `scout` | haiku, medium | 1.0× | open-ended search, no decisions |
| `chore` | opus, low | 1.9× | code whose shape is already decided |
| `dev` | opus, medium | 3.3× | code that needs correctness reasoning |
| `sage` | opus, high | 5.6× | architecture, review, verification |
| `oracle` | opus, xhigh | 8.2× | irreversible, or twice-failed |

Cost is measured $/task-run relative to haiku. Rationale and the full frontier
math live in `model-routing.json`.

Two rules do most of the work: **sonnet-5 is strictly dominated** by opus-low
($0.01 more, +9 index points), and **escalation is triggered by observed
failure**, never by a task sounding important.

## Scope notes

`~/.claude/agents/` is user-level — it applies to every project on the machine.
A project's own `.claude/agents/` wins on name collision, so a repo can override
`dev` locally without touching this.

Per-agent `effort:` in frontmatter overrides the global `effortLevel`. A `grunt`
dispatched from an xhigh session still runs haiku-low.

## Editing

Because install.sh symlinks, editing `~/.claude/agents/dev.md` edits this repo.
Commit and pull elsewhere.

## Do not vendor ~/.claude wholesale

That directory also holds `history.jsonl`, `projects/`, and `sessions/` — your
conversation transcripts. `.gitignore` here blocks them by name in case they
ever get copied in, but the safer habit is to keep this repo a curated subset
rather than a mirror.
