# 02 — Architecture

How the repo is organized, why it's organized that way, and how the cross-cloud lab fits together as a system.

## Repo layout

```
cross-cloud-labs/
├── .claude/                          Claude Code config (this repo's "operating system")
│   ├── CLAUDE.md                     project instructions Claude reads every turn
│   ├── agents/                       5 specialized subagents
│   ├── hooks/                        PreToolUse hook (blocks git push to main)
│   ├── settings.json                 permission tiers (allow / ask / deny)
│   ├── interactive-diagram-template.md
│   └── interactive-docs-template.md
├── .github/                          FUNDING, PR template
├── aws/
│   └── labs/
│       └── vpn-site-to-site/         AWS-side of the VPN lab (Terraform root)
├── azure/
│   └── labs/
│       └── vpn-site-to-site/         Azure-side of the VPN lab (Terraform root)
├── docs/
│   ├── reference-architectures/      Source-of-truth specs per resource and per pattern
│   │   ├── aws/networking/, aws/iam/
│   │   ├── azure/networking/, azure/iam/
│   │   ├── cross-cloud/<pattern>/
│   │   └── claude/                   (when the docs-claude-ref-arch PR lands)
│   └── wiki/                         this directory — narrative walkthrough
├── scripts/                          (helper scripts; currently minimal)
├── teardown-all.sh                   walks every lab and runs its destroy.sh
├── .env.example                      template for local .env
└── README.md                         quick orientation
```

## The "two roots" model

For each lab there are **two Terraform roots** — one per cloud — that share no state:

```
aws/labs/<lab>/         <-- one terraform root (local state)
azure/labs/<lab>/       <-- another terraform root (local state)
```

Why split, when most cross-cloud Terraform setups put both providers in one root?

- **Local state on both sides is a hard rule** (no remote backend bootstrap, no S3 buckets to manage). With one root, the apply on either side fails if the other side's state file isn't on the same machine.
- **Two parallel Claude sessions can work concurrently** without one stepping on the other's plan/apply. (Memory-recorded worktree convention: AWS session in the original clone, Azure session in `cross-cloud-labs-azure` git worktree.)
- **Failure isolation** — Azure-side IAM, capacity, or quota issues don't block AWS work and vice versa.

The trade-off: the two roots need each other's outputs to wire up. With no shared backend, that's a **manual outputs-as-inputs paste**, formalized as the [three-phase apply](03-deploying.md).

## Reference architectures (the "spec layer")

Every resource and every pattern has a Markdown spec under `docs/reference-architectures/`. The spec is canonical — Terraform code and live cloud state are *implementations* of what's documented.

The 10-section template (from [`docs/reference-architectures/README.md`](../reference-architectures/README.md)):

1. Purpose
2. Diagram
3. Components (table — resource, type, role)
4. Networking (IPs, routing, exposure)
5. Identity (IAM/RBAC scopes)
6. Cost (hourly + monthly + dominant driver)
7. Teardown (gotchas, force_destroy flags, soft-delete bypass)
8. Cross-cloud notes (where applicable)
9. Gotchas (non-obvious failure modes)
10. Related Terraform (paths)

Pattern docs (under `cross-cloud/`) are the cross-cutting source of truth — when the Azure spec, AWS spec, and pattern spec all describe the same parameter (e.g., the BGP ASN), the pattern spec wins.

## Cross-cloud lab anatomy — site-to-site VPN

Visual: open [`docs/reference-architectures/cross-cloud/vpn-site-to-site/architecture.html`](../reference-architectures/cross-cloud/vpn-site-to-site/architecture.html) in a browser. Drag-edit-export-PNG.

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

**Locked cross-cloud parameters** (must match exactly on both sides):

| | Value |
|---|---|
| Tunnel 1 inside CIDR | `169.254.21.0/30` |
| AWS-side BGP peer | `169.254.21.1` |
| Azure-side BGP peer | `169.254.21.2` |
| Azure ASN | 65010 |
| AWS VGW ASN | 65020 |
| Azure VNet | `10.10.0.0/16` |
| AWS VPC | `10.20.0.0/16` |

Why pinned: Azure's `local_network_gateway.bgp_settings.bgp_peering_address` requires a known remote APIPA at apply time, so AWS's tunnel inside CIDR can't be left to AWS auto-pick.

## Why these regions

- **AWS `us-east-1`** is the default for the deployer + the labs. Free-tier coverage applies; lowest data-transfer pricing path to the Azure tenant.
- **Azure `eastus2`**, not `eastus`. As of 2026-05, eastus has heavy small-VM SKU capacity restrictions (B-series and DSv2 all return `SkuNotAvailable`); eastus2 has multiple v7 families unrestricted with default 10 vCPU quota. Both pair geographically with `us-east-1` over the public internet.

## Deployer identities — separate per cloud, manually bootstrapped

Each cloud has its own SP/IAM-user. Both are **created manually** (chicken-and-egg with Terraform — the deployer can't create itself), both are **single-purpose**, both have credentials that live only in the local `.env`.

| | AWS | Azure |
|---|---|---|
| Identity | IAM user `terraform-deployer` | App reg + SP `cross-cloud-labs-tf` |
| Auth | Access key + secret | Client ID + secret |
| Permission | `PowerUserAccess` (managed) + scoped IAM inline policy | `Contributor` at subscription scope |
| Self-protection | Inline `Deny iam:*` against own ARN | Cannot mutate role assignments or Entra |
| Secret rotation | 90 days | 1 year |

Detailed specs: [`reference-architectures/aws/iam/deployer.md`](../reference-architectures/aws/iam/deployer.md), [`reference-architectures/azure/iam/deployer.md`](../reference-architectures/azure/iam/deployer.md).

## Tagging convention

Every billable resource on both clouds carries:

```
owner       = zane
project     = cross-cloud-labs
lab         = vpn-site-to-site         # per-lab
managed_by  = terraform
```

AWS uses the provider-level `default_tags` block. Azure applies `tags = var.tags` per resource. This makes orphan detection and bulk teardown possible (`aws ec2 describe-instances --filters Name=tag:project,Values=cross-cloud-labs`, etc.).

## Branch + worktree model

- Single GitHub remote on `main`.
- Feature branches per concern (e.g., `azure-vpn-s2s-deploy`, `docs-wiki`, `docs-cross-cloud-vpn-diagram`).
- **Two working trees** so two Claude sessions don't collide on the same files:
  - AWS session: `/mnt/c/repos/github/cross-cloud-labs/` (the original clone)
  - Azure session: `/mnt/c/repos/github/cross-cloud-labs-azure/` (sibling git worktree)
- Both worktrees share the same `.git` object store but have independent checked-out branches.
- The `block-main-write.sh` PreToolUse hook + the repo `pre-push` hook + the `settings.json` `deny` patterns together enforce "no direct push to main" from any session.

## What now

- Want to deploy: **[03 — Deploying](03-deploying.md)**.
- Want to understand the Claude workflow: **[07 — Claude Code workflow](07-claude-workflow.md)**.
