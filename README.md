# cross-cloud-labs

Hands-on lab repo for AWS learning + Azure↔AWS cross-cloud connectivity. Single owner, single subscription, single AWS account, $100 AWS promo credit, real-money Azure tenant. Designed for **same-day teardown** so daily cost stays in cents, not dollars.

Built and operated using [`claude-dev-toolkit`](https://github.com/zanebarker-ops/claude-dev-toolkit) — every hook, permission rule, subagent, and routine in `.claude/` traces back to a piece of the toolkit. This README is the front-of-repo guide; the [§ How this was built](#-how-this-was-built) section maps each toolkit artifact to where it shows up here.

> **Architecture diagram (8 Mermaid panels):** **<https://zanebarker-ops.github.io/cross-cloud-labs/>**
>
> Topology · Repo layout · Claude operating layer · Guardrails · Daily workflow · Three-phase apply · Teardown path · Toolkit→repo mapping.

---

## Contents

- [What this repo is](#what-this-repo-is)
- [Quick start](#quick-start)
- [Hard rules (non-negotiable)](#hard-rules-non-negotiable)
- [Repo layout](#repo-layout)
- [Architecture in one diagram](#architecture-in-one-diagram)
- [How this was built](#-how-this-was-built) — the claude-dev-toolkit walkthrough
  - [1 · `CLAUDE.md` — the operating guide](#1--claudemd--the-operating-guide)
  - [2 · `settings.json` — three-tier permissions](#2--settingsjson--three-tier-permissions)
  - [3 · Hooks — three layers of guardrails](#3--hooks--three-layers-of-guardrails)
  - [4 · Specialized subagents](#4--specialized-subagents)
  - [5 · Worktree-first dual-session workflow](#5--worktree-first-dual-session-workflow)
  - [6 · Confidence gate + pre-merge multi-agent review](#6--confidence-gate--pre-merge-multi-agent-review)
  - [7 · Reference-architecture-as-source-of-truth](#7--reference-architecture-as-source-of-truth)
  - [8 · Daily teardown discipline](#8--daily-teardown-discipline)
  - [9 · The three-phase apply (cross-cloud specific)](#9--the-three-phase-apply-cross-cloud-specific)
- [Per-piece traceability table](#per-piece-traceability-table)
- [Deviations from the upstream toolkit](#deviations-from-the-upstream-toolkit)
- [How to fork this pattern for your own infra repo](#how-to-fork-this-pattern-for-your-own-infra-repo)
- [Connectivity roadmap](#connectivity-roadmap)
- [Where to read next](#where-to-read-next)

---

## What this repo is

Two Terraform roots — one per cloud — that stand up an IPSec/IKEv2 site-to-site VPN between Azure (eastus2) and AWS (us-east-1) with BGP inside the tunnel. The two roots share no backend; they exchange parameters via a manual outputs-as-inputs paste in three phases. Each lab is independently apply/destroy-able, and `./teardown-all.sh` walks them all at end of day.

The repo also contains the full Claude Code operating environment that drives every change: project-level standing rules, a permission model, runtime hooks, five specialized subagents, and the worktree split that lets two sessions work in parallel without colliding.

| | Azure | AWS |
|---|---|---|
| Region | `eastus2` | `us-east-1` |
| Address space | `10.10.0.0/16` | `10.20.0.0/16` |
| BGP ASN | 65010 | 65020 |
| Tunnel inside CIDR | `169.254.21.0/30` (`.2` Azure, `.1` AWS) | same |
| Workload | VM · `Standard_D2als_v7` (Ubuntu 22.04 LTS) | EC2 · `t3.micro` (AL2023) |

---

## Quick start

```bash
# 1. Clone & enter
git clone https://github.com/zanebarker-ops/cross-cloud-labs.git
cd cross-cloud-labs

# 2. Activate in-repo git hooks (one-time per clone)
./scripts/install-git-hooks.sh   # installs pre-push guard against pushing to main

# 3. Set up credentials
cp .env.example .env
$EDITOR .env   # fill in AWS keys + Azure SP

# 4. Pick a lab
cd aws/labs/vpn-site-to-site   # or azure/labs/...

# 5. Apply (see § Three-phase apply below for the cross-cloud sequence)
set -a && source ../../../.env && set +a
terraform init
terraform plan
terraform apply

# 6. Tear down (end of day, every day)
cd ../../..
./teardown-all.sh
```

---

## Hard rules (non-negotiable)

These come from [`.claude/CLAUDE.md`](.claude/CLAUDE.md) and are encoded into the hook layer and permission tiers. Every page in [`docs/wiki/`](docs/wiki/) assumes them.

1. **Daily teardown.** Every cloud resource must be destroyable on demand. Every lab ships a `destroy.sh`. Repo root has `./teardown-all.sh`.
2. **Cost first.** Before suggesting a billable resource, state its hourly/monthly cost. ExpressRoute, Direct Connect, dedicated hosts are out of scope.
3. **Local Terraform state.** No remote backends. `*.tfstate*` and `.terraform/` are gitignored.
4. **Local `.env` auth only.** Credentials live in `.env` (gitignored). Never commit, echo, or paste secrets in `*.tfvars` files that aren't examples.
5. **Branch + PR workflow.** Never push to `main`. Feature branch + PR.
6. **Reference architecture docs are source of truth.** Code and docs ship together.

---

## Repo layout

```
cross-cloud-labs/
├── .claude/                         Claude Code config — this repo's "operating system"
│   ├── CLAUDE.md                    project-level standing rules (loaded every turn)
│   ├── settings.json                allow / ask / deny permission tiers + env vars + hooks
│   ├── agents/                      5 specialized subagents
│   ├── hooks/                       PreToolUse hook (blocks git commit/push on main)
│   ├── interactive-diagram-template.md
│   └── interactive-docs-template.md
├── .githooks/pre-push               server-bound branch guard (activated by scripts/install-git-hooks.sh)
├── .github/                         FUNDING, PR template
├── aws/labs/<lab>/                  AWS-side Terraform root + destroy.sh + README
├── azure/labs/<lab>/                Azure-side Terraform root + destroy.sh + README
├── docs/
│   ├── index.html                   architecture overview (served on GitHub Pages)
│   ├── reference-architectures/     source-of-truth specs per resource and per pattern
│   │   ├── aws/networking/, aws/iam/
│   │   ├── azure/networking/, azure/iam/
│   │   ├── cross-cloud/<pattern>/
│   │   └── claude/                  ref-arch docs for the Claude config system itself
│   ├── study-guides/                PDFs/PNGs (cloud product mapping, monitoring cheat sheets)
│   └── wiki/                        narrative walkthrough (7 pages — getting started → cost → claude workflow)
├── scripts/install-git-hooks.sh     wires .githooks/ into core.hooksPath
├── teardown-all.sh                  walks every lab and runs its destroy
├── .env.example                     template for local .env
└── README.md                        ← you are here
```

---

## Architecture in one diagram

The full system architecture (cross-cloud topology, the Claude operating layer, defense-in-depth guardrails, the daily workflow loop, the three-phase apply sequence, the teardown path, and the toolkit→repo provenance map) is published as 8 Mermaid panels at:

**<https://zanebarker-ops.github.io/cross-cloud-labs/>**

Source: [`docs/index.html`](docs/index.html) — single self-contained file, no build step, just an embedded Mermaid CDN.

A text rendering of the runtime topology, for the lazy-clicker:

```
                Public Internet  (IPSec/IKEv2 + BGP inside the tunnel)
                        ▲                   ▲
                        │ tunnel 1          │ tunnel 1
   ┌────────────────────┴─┐               ┌─┴─────────────────────┐
   │ Azure (eastus2)      │               │ AWS (us-east-1)       │
   │ VNet 10.10.0.0/16    │               │ VPC 10.20.0.0/16      │
   │  ├─ Public IP (zoned)│               │  ├─ IGW (workload SSM)│
   │  ├─ VPN GW VpnGw1AZ  │  BGP 65010↔65020  ├─ VGW (ASN 65020)  │
   │  │   ASN 65010       │  via 169.254.21.0/30  ├─ Customer GW   │
   │  ├─ LNG → AWS T1     │               │  ├─ VPN Connection    │
   │  ├─ Connection (PSK) │               │  ├─ RT (BGP propagate) │
   │  ├─ NSG (ICMP from   │               │  ├─ SG (ICMP from     │
   │  │   10.20.0.0/16)   │               │  │   10.10.0.0/16)    │
   │  └─ VM D2als_v7      │ ◄ ICMP ─►     │  └─ EC2 t3.micro      │
   │     10.10.1.4        │               │     10.20.1.88        │
   └──────────────────────┘               └───────────────────────┘
```

---

## 🛠 How this was built

Everything below this line is the walkthrough of how the repo was built and operated using [`claude-dev-toolkit`](https://github.com/zanebarker-ops/claude-dev-toolkit). For other teams adopting the same workflow on their own infra repos, this is the section to read.

The toolkit was forged in a SaaS context (TypeScript, Vercel deploys, RLS migrations). Adapting it to a Terraform / two-cloud / daily-teardown context is mostly substitutions — *"deploy" becomes "terraform apply"* and *"preview deploy succeeded" becomes "destroy.sh proven idempotent"* — but the shape of the loop carries over almost unchanged.

The single most important property the toolkit gives this repo: **every change goes through the same loop, whether it was a human or an agent driving.** The branch guard, the cost-impact statement, the ref-arch refresh, the daily teardown — none of them depend on the operator remembering them. They are encoded in `CLAUDE.md`, `settings.json`, and the hook layer.

### 1 · `CLAUDE.md` — the operating guide

**Toolkit source:** [`templates/CLAUDE.md.template`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/templates/CLAUDE.md.template).
**Repo file:** [`.claude/CLAUDE.md`](.claude/CLAUDE.md).

Loaded into the model on every Claude Code turn. This is where standing rules live so they don't have to be re-stated in every prompt.

The file encodes the 6 hard rules above, plus the **audience calibration block** — a table of Azure↔AWS analogues (VPC≈VNet, SG≈NSG, IAM Role≈Managed Identity, ALB≈App Gateway, S3≈Storage Account, etc.) so AWS guidance is always framed in terms the Azure-fluent owner already understands. This pattern is what the toolkit's `CLAUDE.md.template` calls out as "write the calibration that helps the operator most."

### 2 · `settings.json` — three-tier permissions

**Toolkit source:** [`config/settings.json.template`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/config/settings.json.template).
**Repo file:** [`.claude/settings.json`](.claude/settings.json).

Every Bash, Read, and Write tool call routes through these three tiers:

| Tier | Behavior | Examples in this repo |
|---|---|---|
| **`allow`** | Runs without prompting | `terraform plan`, `terraform output`, `terraform validate`, `aws sts get-caller-identity`, `aws ec2 describe-*`, `aws iam list-*` / `get-*`, `aws ce get-cost*`, `az account show`, `az network vnet list`, `az resource list`, `git status`, `git diff`, `git log`, `git push origin <non-main>` |
| **`ask`** | Prompts the operator before running | `terraform apply`, `terraform destroy`, `terraform import`, `terraform state rm/mv`, `aws iam create/delete/attach/put-*`, `aws ec2 create/delete/terminate-*`, `az group create/delete`, `az ad sp create/delete`, `git push --force`, `gh pr merge` |
| **`deny`** | Refused outright | `rm -rf /*`, `git push origin main*`, `git push --force origin main*`, `terraform destroy --auto-approve --target=*`, `Read(./.env)`, `Read(./**/.env)` |

Two design choices worth calling out:

- **Read-only AWS/Azure CLI is universally allowed.** `describe-*` / `list-*` / `get-*` cost nothing and don't mutate, so they should never interrupt the session. This makes Claude an effective state inspector during planning.
- **`Read(./.env)` is denied, not asked.** Even an explicit operator approval shouldn't be enough — credentials should never enter the model context. If the operator wants to see `.env`, they run `! cat .env` themselves; the output stays in their terminal.

The injected env var `TF_IN_AUTOMATION=1` suppresses Terraform's interactive-mode prompts, which would otherwise break tool output parsing.

### 3 · Hooks — three layers of guardrails

**Toolkit source:** the *pattern* of [`hookify-rules/hookify.block-direct-main-dev.local.md`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/hookify-rules/hookify.block-direct-main-dev.local.md), the [`hooks/`](https://github.com/zanebarker-ops/claude-dev-toolkit/tree/master/hooks) PreToolUse pattern, and `hookify.block-env-modification.local.md`.
**Repo files:** [`.claude/hooks/block-main-write.sh`](.claude/hooks/block-main-write.sh), [`.githooks/pre-push`](.githooks/pre-push), the `deny` patterns in [`.claude/settings.json`](.claude/settings.json).

The toolkit teaches **defense in depth**: any single guardrail can be circumvented (a typo, a tool routing edge case, a session-specific permission grant), so independent layers cover each other.

**Layer 1 — `settings.json` deny patterns (static).** Block patterns that match the *literal* command string. Catches the obvious cases (`git push origin main`, `Read(./.env)`) before they get anywhere near the tool runner.

**Layer 2 — `block-main-write.sh` PreToolUse hook (live state).** A hook with matcher `Bash` that runs before every Bash call:

1. Reads tool input as JSON via `jq`.
2. If the command isn't `git commit` or `git push`, exits 0 (allow). Fast skip.
3. Otherwise, reads `git branch --show-current`.
4. If on `main` or `master`, exits 2 (block) with a stderr message; the harness shows it to Claude as feedback.
5. Otherwise, exits 0.

This is the **backstop for cases the static `deny` patterns can't handle**: bare `git push` resolves to the current branch's tracking ref *at runtime*, which isn't pattern-matchable from the literal command text. Fail-closed: if `jq` is missing, the hook exits 1 (block).

**Layer 3 — `.githooks/pre-push` (server-bound, human-driven).** A standard git `pre-push` hook (activated by `scripts/install-git-hooks.sh` setting `core.hooksPath=.githooks`). Catches direct human pushes to `refs/heads/main` or `refs/heads/master`, including deletions. Independent of Claude — protects against `git push` in any terminal, any tool.

Bypass for a one-off legitimate need: `git push --no-verify`. Don't make a habit of it.

### 4 · Specialized subagents

**Toolkit source:** [`templates/agents.md`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/templates/agents.md), the agent dispatch pattern in [`commands/start-task.md`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/commands/start-task.md), and the per-concern agents in the [`pr-review-toolkit`](https://github.com/zanebarker-ops/claude-dev-toolkit/tree/master/plugins/pr-review-toolkit) plugin.
**Repo files:** [`.claude/agents/`](.claude/agents/) — `aws-expert.md`, `azure-expert.md`, `code-reviewer.md`, `security-reviewer.md`, `terraform-reviewer.md`.

Each subagent runs in its own context window, with its own tool subset, against its own narrowly-scoped prompt. The toolkit's argument is two compounding benefits:

1. **Context budget protection.** Long grep-and-read tasks don't pollute the main session.
2. **Specialization.** A reviewer prompt focused on *just* one concern (security, or HCL state safety, or AWS networking) catches things a generalist prompt wouldn't.

| Agent | When to invoke | Notes |
|---|---|---|
| `aws-expert` | AWS service guidance, especially networking and IAM | Always frames via Azure analogue. Refuses Direct Connect (cost). |
| `azure-expert` | vWAN edge cases, Azure-side design validation | Used sparingly — owner is the Azure expert. |
| `code-reviewer` | Diff review for correctness, hidden bugs, repo conventions, cost surprises, teardown story | Output: Blocker / Should fix / Nit. |
| `security-reviewer` | IAM/RBAC scoping, secrets in git, public exposure, SG/NSG holes, SSH from `0.0.0.0/0` | Output: Critical / High / Medium / Info. |
| `terraform-reviewer` | HCL-specific: provider pins, state safety, lifecycle, drift, idempotency | Forbids `lifecycle.prevent_destroy`. |

### 5 · Worktree-first dual-session workflow

**Toolkit source:** [`templates/worktree-workflow.md`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/templates/worktree-workflow.md), [`scripts/claude-session.sh`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/scripts/claude-session.sh) (when running tmux-isolated sessions), and the `enforce-worktree-path.sh` / `check-cross-worktree.sh` hook patterns.
**Repo manifestation:** [`docs/wiki/02-architecture.md` § Branch + worktree model](docs/wiki/02-architecture.md).

The toolkit's argument for worktrees is that **two parallel Claude sessions can collaborate on the same repo without colliding**: shared `.git` object store, independent working trees, independent checked-out branches.

In this repo the split is **by cloud**, because each cloud has its own Terraform root and its own state file:

| Path ownership | Session | Worktree |
|---|---|---|
| `aws/`, `docs/reference-architectures/aws/` | AWS session | original clone |
| `azure/`, `docs/reference-architectures/azure/`, `docs/reference-architectures/cross-cloud/` | Azure session | sibling worktree (`cross-cloud-labs-azure`) |
| `.claude/`, `.github/`, top-level files (`README.md`, `teardown-all.sh`, `.gitignore`) | shared root | touch only with explicit user permission |

Branch convention: `aws-*` for AWS-session branches, `azure-*` for Azure-session branches. This reduces PR conflicts to near-zero in normal operation; shared-root files become the only conflict surface, which is small enough to coordinate manually.

This is also why the **two-roots Terraform pattern** makes sense: one Terraform root per cloud, no shared backend, no `terraform_remote_state`. The seam between the two is a manual outputs-as-inputs paste — the three-phase apply (§9).

### 6 · Confidence gate + pre-merge multi-agent review

**Toolkit source:** [`templates/worktree-workflow.md` § Confidence Gate (8/10 Rule)](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/templates/worktree-workflow.md), [`commands/vote-for-pr.md`](https://github.com/zanebarker-ops/claude-dev-toolkit/blob/master/commands/vote-for-pr.md), and the [`pr-review-toolkit`](https://github.com/zanebarker-ops/claude-dev-toolkit/tree/master/plugins/pr-review-toolkit) plugin.

**Confidence gate (before plan).** The toolkit's 8 dimensions (Requirements / Scope / Codebase / Data model / Security / Edge cases / Testing / Risk) become, for an infra repo:

| Dimension | Infra-flavored question |
|---|---|
| Requirements | What outcome will I be able to demonstrate (ICMP, BGP route count, etc.)? |
| Scope | Which Terraform resources and which ref-arch docs change? |
| Codebase | Have I read the ref-arch doc for the resource I'm modifying? |
| Data model | Are the locked cross-cloud parameters (BGP ASNs, tunnel inside CIDR) still valid? |
| Security | What IAM/RBAC delta does this need? Does it open any public exposure? |
| Edge cases | Does the apply work from a clean `terraform init`? Does `destroy.sh` reverse it? |
| Testing | What's the smallest cloud-side check that proves it's actually working? |
| Risk | Could this strand a billable resource? Could it break the other cloud? |

If confidence < 8/10, the rule is to ask clarifying questions or read the ref-arch doc before continuing — not to start editing.

**Pre-merge multi-agent review (before PR).** The toolkit's `commands/vote-for-pr.md` runs five reviewers; the infra adaptation runs three (`code-reviewer`, `security-reviewer`, `terraform-reviewer`) and reads each output before opening the PR. The `aws-expert` / `azure-expert` agents are consulted on demand *during* the change, not at the merge gate — they are guidance agents, not review agents. Review output gets condensed into the PR body.

### 7 · Reference-architecture-as-source-of-truth

**Toolkit source:** the *pattern* of the toolkit's templates having a stable schema (`feature-prp-template.md`, `CLAUDE.md.template`, `hookify-rules.md`) — every artifact has a known shape so reviewers and agents can find what they need without hunting.
**Repo files:** [`docs/reference-architectures/`](docs/reference-architectures/), with sub-trees for `aws/`, `azure/`, `cross-cloud/`, and `claude/`.

Every resource and every cross-cloud pattern has a Markdown spec. The spec is **canonical** — Terraform code and live cloud state are *implementations* of what's documented. If the code drifts, the doc wins (or the doc is updated deliberately as part of the same PR).

The 10-section schema:

1. Purpose · 2. Diagram · 3. Components (table) · 4. Networking · 5. Identity · 6. Cost · 7. Teardown · 8. Cross-cloud notes · 9. Gotchas · 10. Related Terraform.

Pattern docs (under `cross-cloud/`) are the cross-cutting source of truth: when the Azure spec, the AWS spec, and the pattern spec all describe the same parameter (e.g., the BGP ASN), the **pattern spec wins**. This avoids the n-way drift problem.

### 8 · Daily teardown discipline

**Toolkit source:** the toolkit's CI/CD deploy-gate concept (verify the deployment landed before opening the PR), inverted for infra: **verify the destroy worked before declaring the lab complete**.
**Repo files:** per-lab `destroy.sh`, root [`teardown-all.sh`](teardown-all.sh).

Hard rule 1: every cloud resource must be destroyable on demand. The toolkit's deploy-gate philosophy ("don't ship until the deploy is proven") becomes the daily-teardown rule ("don't end the day until everything is destroyed"). Same shape, opposite direction.

Cost math (from [`docs/wiki/06-cost.md`](docs/wiki/06-cost.md)): with a single VPN GW + workload VM running for ~2 hours per session and torn down at end of day, the lab burns cents/day. Without teardown, it burns ~$36/day on the Azure VPN GW alone — the $100 AWS promo credit and the operator's Azure budget would both evaporate inside a week.

### 9 · The three-phase apply (cross-cloud specific)

The only piece of the workflow that doesn't trace back to the upstream toolkit. It exists because two Terraform roots without a shared backend need each other's outputs in a specific order.

**Phase 1 — Azure standalone.** In the Azure session, set `create_connection = false`. `terraform apply` builds VNet, GatewaySubnet, public IP, VPN Gateway. No connection yet. Output: `azure_gw_public_ip`. Hand it to the AWS session.

**Phase 2 — AWS full apply.** In the AWS session, paste `azure_gw_public_ip` into `aws/labs/vpn-site-to-site/terraform.tfvars`. `terraform apply` builds VPC, IGW, VGW, Customer Gateway (= Azure PIP), VPN Connection. AWS auto-generates the PSK and the tunnel inside CIDR. Outputs: `aws_tunnel1_address`, `aws_tunnel1_psk`, `aws_vgw_asn`. Hand them back to Azure.

**Phase 3 — Azure binding.** In the Azure session, paste the AWS outputs and flip `create_connection = true`. `terraform apply` adds the Local Network Gateway and the Connection (PSK). Tunnel comes up, BGP peer establishes, route exchange starts. ICMP test from the Azure VM to the AWS EC2 (or vice versa) is the success signal.

Why pin tunnel inside CIDR `169.254.21.0/30` and the BGP ASNs (Azure 65010 / AWS 65020): Azure's `local_network_gateway.bgp_settings.bgp_peering_address` requires a known remote APIPA *at apply time*, so AWS's tunnel inside CIDR can't be left to AWS auto-pick.

---

## Per-piece traceability table

| What you see in this repo | Toolkit artifact it came from | Adaptation made |
|---|---|---|
| [`.claude/CLAUDE.md`](.claude/CLAUDE.md) | `templates/CLAUDE.md.template` | Rewrote rules for cloud infra; added Azure↔AWS analogues block |
| [`.claude/settings.json`](.claude/settings.json) allow/ask/deny | `config/settings.json.template` | Replaced JS/TS commands with Terraform + AWS CLI + Azure CLI tiers |
| [`.claude/hooks/block-main-write.sh`](.claude/hooks/block-main-write.sh) | `hookify-rules/hookify.block-direct-main-dev.local.md` (concept) + `hooks/` PreToolUse pattern | Folded the rule into one PreToolUse script reading live branch state |
| [`.githooks/pre-push`](.githooks/pre-push) | `hookify.block-direct-main-dev.local.md` (concept), git-side counterpart | Server-bound git hook for human-driven pushes |
| `Read(./.env)` deny in settings | `hookify.block-env-modification.local.md` + `hooks/block-env-read.sh` | Combined into a `Read` deny pattern in settings |
| [`.claude/agents/`](.claude/agents/) (5 agents) | `templates/agents.md` + `pr-review-toolkit` per-concern agents | 5 cloud-specialized agents, narrower than the toolkit's 26 |
| Two-worktree split (AWS / Azure) | `templates/worktree-workflow.md` + `enforce-worktree-path.sh` | Split by *cloud ownership* instead of feature ownership |
| Confidence gate before Terraform plan | `templates/worktree-workflow.md` § 8/10 Rule | 8 questions rephrased for infra (cost/teardown replace tests/types) |
| Pre-merge 3-agent review | `commands/vote-for-pr.md` + `pr-review-toolkit` | 3 reviewers, not 5 (no test/type-design agents — irrelevant for HCL) |
| `docs/reference-architectures/` 10-section schema | The toolkit's *templates-have-stable-shapes* discipline | New schema authored for cloud resources |
| [`teardown-all.sh`](teardown-all.sh) | The toolkit's deploy-gate concept (verify-deploy-then-PR) | Inverted for infra: verify-destroy-then-end-of-day |
| Three-phase apply | n/a | New, cross-cloud specific |
| [`docs/index.html`](docs/index.html) (architecture overview) | n/a | New — published via GitHub Pages |
| `.claude/interactive-diagram-template.md` | n/a | New — single-file editable HTML diagram pattern |

---

## Deviations from the upstream toolkit

In the spirit of "every hook exists because something went wrong without it" (the toolkit's own framing), here is what was *not* adopted from upstream and why. None of these are criticisms of the toolkit — they are mismatches between an infra repo and the SaaS context the toolkit was forged in.

| Toolkit piece | Why not adopted here |
|---|---|
| `oxlint` and `lint-changed.sh` | No JS/TS in this repo. Terraform's `terraform fmt -check` and `terraform validate` are the analogues; both are in the `allow` tier of settings. |
| `check-deploy.sh` (Vercel/Netlify deploy gate) | No web preview deployment exists. The success signal is the cloud-side test (BGP route count, ICMP RTT), which is operator-run. |
| `wsl-crash-recovery.sh` and tmux session manager | Optional layer — used when the operator runs multiple long Claude sessions on WSL, not part of the repo's required workflow. |
| 13 hookify rules | Most are SaaS-specific (RLS, security definer, console.log, ESLint). Only the branch-protection and env-protection rules apply; both are folded into hooks/settings rather than carried as separate rule files. |
| 26 agent commands | Most are SaaS-shaped (frontend-developer, sales-onboarding, customer-support, marketing-content). Only the review-flavored ones map directly. |
| Beads (`bd`) for task tracking | Not in use. GitHub issues + branch names carry equivalent state for a single-operator infra repo. |

---

## How to fork this pattern for your own infra repo

If you want to apply this same pattern to your own AWS / Azure / GCP / Terraform repo:

1. **Start from the toolkit, not from this repo.** Run `claude-dev-toolkit/install.sh` against your project. You get the JS/TS-shaped baseline.
2. **Strip the JS/TS pieces.** Remove `oxlint`, `lint-changed.sh`, `check-deploy.sh`, the JS-flavored hookify rules. Keep the hook scaffolding, `settings.json` shape, agent dispatch concept, and the worktree workflow doc.
3. **Rewrite `CLAUDE.md`** with your hard rules. The 6 rules in this repo are a reasonable starting point for any "cost-bounded daily-teardown lab repo." For a production infra repo, replace daily-teardown with your real change-management constraints (change windows, drift detection, blast radius).
4. **Rewrite `settings.json`** for your tooling: `terraform plan / validate / output` and read-only cloud CLI in `allow`; `apply / destroy / IAM mutations` in `ask`; `push to main / read .env` in `deny`.
5. **Specialize the subagents** for your cloud(s) and your concerns. Aim for 3–5 narrow agents, not 20 broad ones. Always include `security-reviewer` and `terraform-reviewer` (or their HCL-equivalent for your IaC tool).
6. **Decide your worktree split.** Per-cloud (this repo), per-environment (dev/staging/prod), or per-feature — pick the one that minimizes cross-worktree path collisions.
7. **Write the ref-arch schema** for your resource types. Keep it stable so reviewers can scan the same sections every time.
8. **Author your teardown story** *before* authoring your apply story. Hard rule 1 is the one that prevents stranded billable resources. Without it, every other rule is decoration.

---

## Connectivity roadmap

| # | Lab | Status |
|---|-----|--------|
| 1 | Site-to-site IPSec VPN (Azure VPN GW ↔ AWS VGW/TGW) | scaffolded; cross-cloud apply in progress |
| 2 | Azure Virtual WAN with VPN site to AWS | not started |
| 3 | AWS Transit Gateway as multi-VPC + cross-cloud hub | not started |

ExpressRoute and Direct Connect are explicitly **out of scope** (cost).

---

## Where to read next

- **Architecture diagram (Mermaid, 8 panels):** <https://zanebarker-ops.github.io/cross-cloud-labs/>
- **Narrative walkthrough:** [`docs/wiki/`](docs/wiki/README.md) — getting started, architecture, deploying, tearing down, troubleshooting, cost, Claude workflow
- **Reference architectures (source of truth):** [`docs/reference-architectures/`](docs/reference-architectures/)
- **Study guides:** [`docs/study-guides/`](docs/study-guides/) — cloud product mapping, monitoring cheat sheets, cloud databases overview
- **Toolkit:** <https://github.com/zanebarker-ops/claude-dev-toolkit>
