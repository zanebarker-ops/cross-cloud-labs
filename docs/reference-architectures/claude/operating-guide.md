# Claude operating guide (`CLAUDE.md`)

Source-of-truth doc for `.claude/CLAUDE.md` — the project-level instructions Claude Code loads on every turn.

## 1. Purpose

`CLAUDE.md` is the standing instruction set for any Claude session opened against this repo. It encodes the project's hard rules, repo layout, tagging convention, audience calibration, and the connectivity roadmap so that any session starts with the same context regardless of who launched it.

It is **not** documentation for humans (the `README.md` plays that role). It is documentation for Claude.

## 2. Components

| Section | Role |
|---|---|
| Hard rules | The six non-negotiables: daily teardown, cost-first, local TF state, local `.env` auth, branch+PR workflow, ref-arch docs as source of truth |
| Repo layout | Tree showing `.claude/`, `aws/`, `azure/`, `labs/`, `docs/`, `teardown-all.sh`, `.env.example` |
| Tagging convention | Required `owner` / `project` / `lab` / `managed_by` tags on every cloud resource |
| Audience calibration | Azure↔AWS analogue table; instruction to explain AWS, not Azure |
| Connectivity roadmap | VPN-first → vWAN → TGW; ExpressRoute and Direct Connect explicitly out of scope |
| Subagent usage | Pointer to which subagent fits which task |
| Workflow expectations | Plan-then-implement, doc-on-resource-add, destroy-before-complete, cost-impact on PRs |

## 3. Trigger / scope

Loaded automatically by Claude Code on every turn, for every session opened with a working directory under this repo. There is no opt-out — these rules apply unconditionally.

User-level memory (`~/.claude/projects/.../memory/MEMORY.md`) is layered on top per session but does not replace `CLAUDE.md`.

## 4. Behavior contract

The hard rules are the contract. In summary, Claude must:

- **Daily teardown:** never create a cloud resource without a `destroy.sh` path. Refuse to scaffold anything that can't be torn down.
- **Cost first:** state hourly/monthly cost before suggesting a billable resource. Refuse ExpressRoute, Direct Connect, dedicated hosts, or anything with a high standing charge unless explicitly asked.
- **Local TF state:** no remote backend blocks. State and `.terraform/` stay gitignored.
- **Local `.env` auth:** never echo, commit, or place secrets in non-example tfvars.
- **Branch + PR:** never push to `main`. Always feature-branch and PR. (Hard-enforced by the `block-main-write.sh` PreToolUse hook — see [`hooks.md`](hooks.md).)
- **Ref-arch docs canonical:** when scaffolding any AWS/Azure resource, write/update the matching doc under `docs/reference-architectures/<cloud>/` in the same PR.

## 5. Cost / blast radius

Non-monetary. If this file drifts out of sync with the actual rules:

- A new contributor (human or AI) gets stale guidance and may, e.g., create a NAT Gateway thinking it's free, push to main, or skip a destroy script.
- The reviewer subagents key off these rules — drift here propagates into review noise or missed catches.

## 6. Gotchas

- **CLAUDE.md is loaded, not chosen.** There is no UI to disable it. If a rule needs to change, the change must happen here — instructing the user "ignore that rule for this session" is fragile and will not survive a new conversation.
- **"Cost first" depends on Claude knowing current prices.** Prices in CLAUDE.md and the cloud ref-arch docs are point-in-time estimates; treat them as rough not authoritative when budget decisions hinge on them.
- **Audience calibration** ("the user is Azure-fluent") is the reason cloud docs lead with AWS↔Azure analogues. If the audience changes (a different contributor uses the repo), this section needs an explicit edit — Claude won't recalibrate on its own.

## 7. Related files

- `.claude/CLAUDE.md` — the file this doc covers
- [`subagents.md`](subagents.md) — the subagents this guide references
- [`hooks.md`](hooks.md) — the hook that enforces the "never push to main" rule
- [`settings.md`](settings.md) — the permission model that backstops the cost / destroy rules
- [`routines.md`](routines.md) — how the rules manifest as recurring workflows
- [`../README.md`](../README.md) — the ref-arch system that hard rule #6 mandates
