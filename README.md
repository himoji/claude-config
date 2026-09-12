# madik-claude-config

A Claude Code plugin marketplace. Currently ships one plugin.

## model-routing

Cost-tiered subagents. Eight agents, each pinning its own model and reasoning
effort in frontmatter — which **overrides the session's global `effortLevel`**.
That override is the whole mechanism: a `grunt` dispatched from an xhigh session
still runs haiku-low, so lookups stop being billed at orchestrator rates.

| agent | model / effort | cost | for |
|---|---|---|---|
| `grunt` | haiku, low | 1.0× | run it and report; no judgement |
| `scout` | haiku, medium | 1.0× | open-ended search, no decisions |
| `chore` | opus, low | 1.9× | code whose shape is already decided |
| `dev` | opus, medium | 3.3× | code that needs correctness reasoning |
| `critic` | fable, medium | 4.5× | ordinary review, verify a claim — the default thinker |
| `sage` | fable, high | 6.5× | architecture, auth/money/migration diffs, or `critic` failed |
| `judge` | opus, xhigh | 8.2× | irreversible but recoverable, or `dev`+`sage` failed |
| `oracle` | fable, xhigh | 12.0× | unrecoverable, or `judge` failed |

Cost is measured $/task-run relative to haiku. `fable, max` (16.8×) is a
ceiling, not a rung — used only when the user asks for it by name.

Three findings do most of the work. **sonnet-5 and fable-low are strictly
dominated** — opus-low beats sonnet-5 for $0.01 more, opus-med beats fable-low
for $0.05 *less* — so neither appears in the ladder. **The think side has four
rungs, not two.** 1.1.0 put `sage` on fable-high and `oracle` on fable-xhigh
because those are the best points per index point on the convex hull — but that
made every judgement call cost 2× a `dev` and the ladder jump 1.85× again to
`oracle`. 1.2.0 adds `critic` (fable, medium — $0.43 cheaper per call than
`sage`) as the default thinker and `judge` (opus, xhigh, the 1.0 `oracle` —
$0.85 cheaper than fable-xhigh) as the first peak rung; no step is now more than
1.5×. And the **marginal cost per index point jumps 6.8× at `dev` → `critic`**,
which is why escalation is triggered by observed failure rather than by
anticipated difficulty: below that cliff guessing high costs pennies, above it
guessing high is the main way to waste money.

Also ships:

- a **SessionStart hook** injecting the one-page dispatch policy, because a
  policy loaded on demand cannot influence a decision already made
- a **`model-routing` skill** with the frontier math, escalation rules, and
  instructions for recomputing the table when prices move

## Install

```bash
/plugin marketplace add himoji/claude-config
/plugin install model-routing@madik-claude-config
```

From a local clone instead:

```bash
/plugin marketplace add ~/Documents/git/claude-config
/plugin install model-routing@madik-claude-config
```

Or declaratively in `~/.claude/settings.json` — no interactive session needed,
which is what makes this work on a headless box:

```json
{
  "extraKnownMarketplaces": {
    "madik-claude-config": {
      "source": { "source": "github", "repo": "himoji/claude-config" }
    }
  },
  "enabledPlugins": { "model-routing@madik-claude-config": true }
}
```

Agents and hooks load at session start — open a new session afterwards.

Non-interactively, from any shell:

```bash
claude plugin marketplace add himoji/claude-config
claude plugin install model-routing@madik-claude-config
```

### Verify it loaded

```bash
claude plugin list
ls ~/.claude/plugins/cache/madik-claude-config/model-routing/*/
```

The second command must list `agents/`, `hooks/`, `skills/`, `model-routing.md`
and `.claude-plugin/`. In a new session the eight agents show up in the Agent
tool's type list and `model-routing:model-routing` in the skill list.

### If Claude never picks it up

The failure mode seen 2026-09: `enabledPlugins` said true, the marketplace
clone was complete, but the install copy under
`~/.claude/plugins/cache/madik-claude-config/model-routing/<version>/` was an
empty directory holding only `.in_use/` lock files. Claude Code then loads
nothing — no agents, no skill, no hook — and reports no error. Fix:

```bash
claude plugin marketplace update madik-claude-config
claude plugin uninstall model-routing@madik-claude-config
claude plugin install model-routing@madik-claude-config
```

then check the cache directory again. Bumping `version` in both manifests
forces a fresh cache directory on reinstall, which is why releases bump it.

## Layout

```
.claude-plugin/marketplace.json      marketplace manifest
plugins/model-routing/
  .claude-plugin/plugin.json         plugin manifest
  agents/*.md                        8 agents (auto-discovered)
  hooks/hooks.json                   SessionStart registration
  hooks/session-start.sh             emits the policy
  model-routing.md                   the policy
  model-routing.json                 prices, frontier, escalation rules
  skills/model-routing/SKILL.md      the cost model
install.sh                           fallback: symlink into ~/.claude
settings.reference.json              portable settings subset (manual merge)
```

`agents/` and `hooks/hooks.json` are discovered by convention, not declared in
`plugin.json`. Only the non-default `skills/` location needs a manifest key.

## install.sh is the fallback

If you want the files in `~/.claude` without the plugin system:

```bash
./install.sh            # symlink into ~/.claude
./install.sh --unlink   # remove those links
```

**Pick one path.** Running the symlink installer *and* installing the plugin
gives you eight duplicate agent names and the policy injected twice per session.
`--unlink` before installing the plugin.

## Editing

The plugin directory is the single source of truth — there are no duplicated
copies to drift. Edit `plugins/model-routing/agents/dev.md`, commit, pull
elsewhere.

When prices or index scores change, edit `model-routing.json` first, then
recompute before touching prose. Check whether any point has become dominated,
whether the convex-hull walk still lands on the same rungs, and whether the
cliff has moved — the ladder's shape follows from where it sits. Bump `version`
in `plugin.json` and `marketplace.json` so the reinstall lands in a fresh cache
directory.

## Do not vendor ~/.claude wholesale

That directory also holds `history.jsonl`, `projects/`, and `sessions/` — your
conversation transcripts. `.gitignore` blocks them by name in case they are ever
copied in, but the safer habit is keeping this repo a curated subset rather than
a mirror.
