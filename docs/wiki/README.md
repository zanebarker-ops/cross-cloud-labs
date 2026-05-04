# cross-cloud-labs — Wiki

Hands-on lab repo for AWS learning + Azure↔AWS cross-cloud connectivity. Single owner, single subscription / single AWS account, $100 AWS promo credit, real-money Azure tenant. Designed for **same-day teardown** so daily cost stays in cents, not dollars.

The wiki is the high-level narrative. The authoritative per-resource specs live in [`docs/reference-architectures/`](../reference-architectures/) and the project-level rules live in [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md). When the wiki and a ref-arch doc disagree, the ref-arch doc wins.

## Pages

| Page | What it covers |
|---|---|
| [01 — Getting started](01-getting-started.md) | Prerequisites, account/subscription setup, `.env` layout, first `terraform init` |
| [02 — Architecture](02-architecture.md) | Repo layout, reference-architecture system, cross-cloud lab anatomy, why local state |
| [03 — Deploying](03-deploying.md) | Step-by-step three-phase apply for the site-to-site VPN lab |
| [04 — Tearing down](04-tearing-down.md) | Per-lab `destroy.sh`, `./teardown-all.sh`, what to watch for |
| [05 — Troubleshooting](05-troubleshooting.md) | CRLF in `.env`, SKU/capacity/quota walls, az subscription mismatch, ARM 429s |
| [06 — Cost](06-cost.md) | Per-resource hourly/monthly cost, daily-teardown math, stranded-resource list |
| [07 — Claude Code workflow](07-claude-workflow.md) | How `.claude/` is configured (subagents, hooks, settings, routines) |

## Hard rules (non-negotiable)

These come from [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md). Every page in this wiki assumes them:

1. **Daily teardown.** Every cloud resource must be destroyable on demand. Every lab ships a `destroy.sh`. Repo root has `./teardown-all.sh`.
2. **Cost first.** Before suggesting a billable resource, state its hourly/monthly cost. ExpressRoute, Direct Connect, dedicated hosts are out of scope.
3. **Local Terraform state.** No remote backends. `*.tfstate*` and `.terraform/` are gitignored.
4. **Local `.env` auth only.** Credentials live in `.env` (gitignored). Never commit, echo, or paste secrets in `*.tfvars` files that aren't examples.
5. **Branch + PR workflow.** Never push to `main`. Feature branch + PR.
6. **Ref-arch docs are source of truth.** Code and docs ship together.

## What's deployed today (working state, 2026-05-04)

| | Azure | AWS |
|---|---|---|
| Region | `eastus2` | `us-east-1` |
| Address space | `10.10.0.0/16` | `10.20.0.0/16` |
| BGP ASN | 65010 | 65020 |
| Tunnel endpoint | Azure VPN GW (VpnGw1AZ) public IP | AWS VGW tunnel 1 IP |
| Workload VM | `Standard_D2als_v7` (Ubuntu 22.04 LTS) | `t3.micro` (AL2023) |
| Tunnel state | Connected, BGP route accepted | Tunnel 1 UP, 1 BGP route accepted |

Tunnel inside CIDR: `169.254.21.0/30` (AWS = `.1`, Azure = `.2`).

## Quick links

- Cross-cloud topology (interactive HTML): [`reference-architectures/cross-cloud/vpn-site-to-site/architecture.html`](../reference-architectures/cross-cloud/vpn-site-to-site/architecture.html)
- Cross-cloud spec: [`reference-architectures/cross-cloud/vpn-site-to-site/README.md`](../reference-architectures/cross-cloud/vpn-site-to-site/README.md)
- Azure VPN GW spec: [`reference-architectures/azure/networking/vpn-gateway.md`](../reference-architectures/azure/networking/vpn-gateway.md)
- AWS VGW spec: [`reference-architectures/aws/networking/vpn-site-to-site.md`](../reference-architectures/aws/networking/vpn-site-to-site.md)
- Azure deployer SP spec: [`reference-architectures/azure/iam/deployer.md`](../reference-architectures/azure/iam/deployer.md)
- AWS deployer IAM spec: [`reference-architectures/aws/iam/deployer.md`](../reference-architectures/aws/iam/deployer.md)
