#!/usr/bin/env bash
# Inject the model-routing policy at session start.
#
# Plugins cannot append to CLAUDE.md, so stdout from this hook is how the
# dispatch policy reaches the orchestrator's context. It must be always-on:
# a policy loaded on demand cannot influence a decision already made.
#
# Cost note: this text is billed once per session, on the order of ~900
# tokens. It pays for itself the first time it moves one lookup off the
# think tier. Keep model-routing.md tight for that reason.

set -uo pipefail

POLICY="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/model-routing.md"

# Never break a session start. A missing policy is a silent no-op.
[ -r "$POLICY" ] || exit 0

cat "$POLICY"
