# Claude Code reference architecture

Source-of-truth docs for the `.claude/` configuration in this repo: the operating guide, subagents, hooks, permission settings, the project's recurring workflows ("routines"), and the interactive HTML templates.

The same ref-arch rule applies as for cloud resources: **if the file under `.claude/` and the doc here disagree, the doc is canonical** — either fix the file, or update the doc deliberately as part of the change.

## What lives here

| Doc | Covers | File(s) under `.claude/` |
|---|---|---|
| [`operating-guide.md`](operating-guide.md) | The repo's hard rules and audience calibration that Claude reads on every turn | `CLAUDE.md` |
| [`subagents.md`](subagents.md) | The 5 specialized subagents and when to invoke each | `agents/*.md` |
| [`hooks.md`](hooks.md) | PreToolUse hooks (the main-branch write guard) | `hooks/*.sh` + `settings.json` `hooks` block |
| [`settings.md`](settings.md) | Permission allow/ask/deny lists and env vars | `settings.json` |
| [`routines.md`](routines.md) | Recurring workflows the user expects every change to follow | none directly — encoded across `CLAUDE.md`, `settings.json`, hooks, and reviewer agents |
| [`templates.md`](templates.md) | Interactive HTML diagram + docs templates | `interactive-diagram-template.md`, `interactive-docs-template.md` |

## Why these docs deviate from the 10-section template

The repo-wide ref-arch template (see [`../README.md`](../README.md) §"Required sections") is shaped around cloud resources: Networking, Identity, Cost, Teardown, Cross-cloud notes. Most of those don't apply to Claude config — there's nothing to network, no IAM scope, no monthly cost, no destroy step.

Claude docs use this adapted template instead:

1. **Purpose** — what the file/feature does and when it kicks in.
2. **Components** — the actual files and the moving parts inside them.
3. **Trigger / scope** — what causes Claude (or the harness) to read or run it.
4. **Behavior contract** — what it makes Claude do or refuse to do.
5. **Cost / blast radius** — non-monetary cost: what bad behavior is possible if this is wrong (e.g., a permission too broad, a hook silently failing).
6. **Gotchas** — non-obvious failure modes.
7. **Related files** — paths under `.claude/`, plus any cloud-side docs that reference the same rule.

Sections that don't apply to a given doc are simply omitted — better than padding.

## Why "routines" is its own doc

`routines.md` is the slot for **how we work**, not **what's in `.claude/`**. The hard rules in `CLAUDE.md` (daily teardown, branch+PR, doc-as-source-of-truth) drive recurring workflows like the phased cross-cloud apply, the cost-impact statement on PRs, and the post-resource doc-update step. Those are routines whether or not they're enforced by a hook or a permission.

If a routine ever does become a scheduled remote agent (via the `/schedule` skill), it gets documented in this same file with its cron spec — but until then, "routine" here means "expected workflow," not "scheduled job."
