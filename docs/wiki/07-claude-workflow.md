# 07 — Claude Code workflow

How `.claude/` makes this repo work consistently across sessions and what guardrails are in place. Full per-file specs live under [`docs/reference-architectures/claude/`](../reference-architectures/claude/) (when the `docs-claude-ref-arch` PR lands; see "Open work" below).

## What lives in `.claude/`

```
.claude/
├── CLAUDE.md                       project-level standing instructions
├── settings.json                   permission tiers + env vars + hook registrations
├── agents/                         5 specialized subagents
│   ├── aws-expert.md
│   ├── azure-expert.md
│   ├── code-reviewer.md
│   ├── security-reviewer.md
│   └── terraform-reviewer.md
├── hooks/
│   └── block-main-write.sh         PreToolUse hook: blocks git commit/push on main
├── interactive-diagram-template.md HTML skeleton for editable diagrams
└── interactive-docs-template.md    HTML skeleton for editable docs
```

## `CLAUDE.md` — the operating guide

Loaded on every Claude Code turn. Encodes the **6 hard rules** (daily teardown, cost-first, local TF state, local `.env` auth, branch+PR, ref-arch as source of truth) plus the repo layout, tagging convention, audience calibration (Azure↔AWS analogues), connectivity roadmap, and subagent dispatch table.

This is what the wiki, the reviewer agents, and any future contributor (human or AI) all read off.

## Subagents — when to invoke each

| Agent | When to use |
|---|---|
| `aws-expert` | AWS service guidance — networking, IAM, cross-cloud connectivity. Always frames via Azure analogue. Refuses Direct Connect. |
| `azure-expert` | Use sparingly — owner is the Azure expert. Reserved for vWAN edge cases, Azure-side design validation. |
| `code-reviewer` | Diff review for correctness, hidden bugs, repo conventions, cost surprises, teardown story. Output: Blocker / Should fix / Nit. |
| `security-reviewer` | IAM/RBAC scoping, secrets in git, public exposure, SG/NSG holes, SSH from `0.0.0.0/0`. Output: Critical / High / Medium / Info. |
| `terraform-reviewer` | HCL-specific: provider pins, state safety, lifecycle, drift, idempotency. Forbids `lifecycle.prevent_destroy`. |

Subagents run in their own context window with their own tool subset. They protect the main session's context budget on long-running grep/research tasks and specialize the prompt for review work.

## `settings.json` — permission tiers

Three tiers gate every Bash/Read tool call:

| Tier | Examples | Behaviour |
|---|---|---|
| **`allow`** | `terraform plan`, `terraform output`, `aws sts get-caller-identity`, `aws ec2 describe-*`, `az account show`, `git status`, `git diff`, `git push origin <non-main>` | Runs immediately, no prompt |
| **`ask`** | `terraform apply`, `terraform destroy`, `aws iam create-*`, `aws ec2 terminate-*`, `az group delete`, `gh pr merge` | Prompts user before running |
| **`deny`** | `rm -rf /*`, `git push origin main*`, `git push --force origin main*`, `Read(./.env)`, `Read(./**/.env)` | Refused outright |

The `Read(./.env)` deny is why Claude can't peek at credentials even when asked — the user has to run any `.env` inspection themselves (e.g., via `! cat .env` in the prompt).

Env var injected: `TF_IN_AUTOMATION=1` (suppresses Terraform's interactive-mode prompts in tool output).

## `hooks/block-main-write.sh` — runtime branch guard

A PreToolUse hook with matcher `Bash`. Before every Bash call, the script:

1. Reads tool input as JSON via `jq`
2. If the command isn't `git commit` or `git push`, exits 0 (allow) — fast skip for everything else
3. Otherwise, reads `git branch --show-current`
4. If on `main` or `master`, exits 2 (block) with a stderr message; the harness shows it to Claude
5. Otherwise, exits 0

This is a **backstop** for the case the static `deny` patterns can't handle: bare `git push` resolves to the current branch's tracking ref at runtime, which isn't pattern-matchable. The hook reads live state.

Fail-closed: if `jq` is missing, the hook exits 1 (block) — better to break than to silently allow a push to main.

## Routines — recurring workflows

These are **expected workflows** every change is supposed to follow. They emerge from `CLAUDE.md` + `settings.json` + hooks + reviewer subagents working together; named here so they're invokable explicitly.

| # | Routine | Trigger |
|---|---|---|
| 1 | Plan → confirm → apply | Any non-trivial change |
| 2 | Phased cross-cloud apply | Any cross-cloud lab (see [03 — Deploying](03-deploying.md)) |
| 3 | Daily teardown | End of working day (see [04 — Tearing down](04-tearing-down.md)) |
| 4 | Branch + PR (never push to main) | Every change |
| 5 | Doc-as-source-of-truth | Any PR adding/modifying a resource |
| 6 | Pre-merge review (multi-agent) | Before opening/merging a non-trivial PR |
| 7 | Cost-impact statement on PR | Any PR adding a billable resource (see [06 — Cost](06-cost.md)) |
| 8 | Ref-arch refresh after deploy | When deploy reveals code-vs-doc drift |

## Two parallel sessions, two worktrees

Two Claude Code sessions can collaborate on this repo without colliding:

- **AWS session** runs in the original clone (`/mnt/c/repos/github/cross-cloud-labs/`)
- **Azure session** runs in a sibling git worktree (`/mnt/c/repos/github/cross-cloud-labs-azure/`)

The two share the same `.git` object store (so they see each other's branches and commits) but have independent working trees (so `git checkout` on one doesn't yank files out from under the other).

Path ownership:
- `aws/`, `docs/reference-architectures/aws/` → AWS session
- `azure/`, `docs/reference-architectures/azure/`, `docs/reference-architectures/cross-cloud/` → Azure session
- Shared root files (`.claude/`, `.github/`, top-level `README.md`, `teardown-all.sh`, `.gitignore`) → touch only with explicit user permission to avoid PR conflicts

Branch convention: `aws-*` for AWS-session branches, `azure-*` for Azure-session branches.

## Interactive HTML templates

Two reusable single-file templates for browser-editable artifacts:

- `interactive-diagram-template.md` — used by [`reference-architectures/cross-cloud/vpn-site-to-site/architecture.html`](../reference-architectures/cross-cloud/vpn-site-to-site/architecture.html) and any future topology/architecture diagram. Drag-edit-save-export-PNG. Mandatory environment color scheme when items are env-scoped (Dev=green, Test=blue, Prod=red, etc.).
- `interactive-docs-template.md` — for editable technical docs with multiple section types (text, table, code, callout, collapsible, TOC). Auto-stacks sections with measured heights.

Use them when the user asks for "something I can edit in the browser." Don't rewrite the JS engine inline — just replace placeholder boxes/sections with content.

## Open work in flight (2026-05-04)

Pending PRs in branch state:

| Branch | What it does | State |
|---|---|---|
| `azure-vpn-s2s-deploy` | Region switch (eastus → eastus2), SKU iteration (B1s → D2als_v7), VPN GW SKU bump (VpnGw1 → VpnGw1AZ), zoned PIP, doc updates across 3 ref-arch files | Local commits, not pushed |
| `docs-claude-ref-arch` | Adds `docs/reference-architectures/claude/` ref-arch section + interactive `architecture.html` for the Claude config system | Local commit, not pushed |
| `docs-cross-cloud-vpn-diagram` | Adds [`docs/reference-architectures/cross-cloud/vpn-site-to-site/architecture.html`](../reference-architectures/cross-cloud/vpn-site-to-site/architecture.html), the cross-cloud topology diagram | Local commit, not pushed |
| `docs-wiki` | This wiki | This branch |

Each is single-purpose so they can land in any order without conflict.

## What now

- Want to know what each ref-arch doc covers: [`docs/reference-architectures/README.md`](../reference-architectures/README.md).
- Back to deploy-mode: **[03 — Deploying](03-deploying.md)**.
- Wiki done: nothing more to read here.
