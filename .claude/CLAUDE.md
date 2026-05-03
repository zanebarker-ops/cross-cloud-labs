# cross-cloud-labs — Claude operating guide

Hands-on lab repo for AWS learning + Azure↔AWS cross-cloud connectivity. Owner is an Azure expert who is new to AWS.

## Hard rules (do not violate)

1. **Daily teardown.** Every cloud resource must be destroyable on demand. Every lab ships a `destroy.sh`. The repo root has `./teardown-all.sh`. Never create a resource without a destroy path.
2. **Cost first.** $100 AWS promo credit must last ~6 months. Azure is real-money. Before suggesting a resource, state its hourly/monthly cost. Refuse to scaffold ExpressRoute, Direct Connect, dedicated hosts, or anything with a high standing charge unless explicitly asked.
3. **Local Terraform state.** No remote backends. `*.tfstate*` and `.terraform/` are gitignored.
4. **Local `.env` auth only.** Credentials live in `.env` (gitignored). Never commit secrets, never echo them, never put them in `*.tfvars` files that aren't examples.
5. **Branch + PR workflow.** Never push to `main`. Always work on a feature branch and open a PR.
6. **Reference architecture docs are source of truth.** Every AWS/Azure resource we build needs a doc under `docs/reference-architectures/<cloud>/`. If code and doc disagree, the doc is canonical (or update the doc deliberately as part of the change).

## Repo layout

```
.claude/                       Claude Code config (this file, agents, settings)
.github/                       GitHub config (FUNDING, workflows if added later)
aws/                           AWS-only Terraform building blocks (modules, primitives)
azure/                         Azure-only Terraform building blocks
labs/                          Cross-cloud labs — each is independently apply/destroy-able
  └── <lab-name>/
       ├── main.tf
       ├── variables.tf
       ├── outputs.tf
       ├── destroy.sh          Wraps `terraform destroy -auto-approve`
       └── README.md           Lab-specific notes
docs/
  ├── reference-architectures/
  │    ├── aws/                AWS service reference docs (source of truth)
  │    └── azure/              Azure service reference docs
  └── study-guides/            PDFs/PNGs (cloud product mapping, monitoring, databases)
teardown-all.sh                Walks all labs and destroys
.env.example                   Template for local .env
```

## Tagging convention

Every cloud resource must carry these tags (AWS) / tags block (Azure):

```
owner       = zane
project     = cross-cloud-labs
lab         = <lab-name>           # e.g. vpn-site-to-site
managed_by  = terraform
```

This makes orphan detection and bulk teardown possible.

## Audience calibration

- The user is deeply Azure-fluent. When explaining AWS concepts, use Azure analogues:
  VPC ≈ VNet · Subnet ≈ Subnet · SG ≈ NSG · Route Table ≈ Route Table · IGW ≈ Internet egress on VNet · NAT GW ≈ NAT Gateway · TGW ≈ vWAN hub · VGW ≈ VPN Gateway · ALB ≈ App Gateway · NLB ≈ Standard LB · IAM Role ≈ Managed Identity · S3 ≈ Storage Account (blob) · KMS ≈ Key Vault.
- Don't over-explain Azure. Do explain AWS.

## Connectivity roadmap

1. **Site-to-site IPSec VPN** — Azure VPN Gateway ↔ AWS VGW (or TGW VPN attachment). v1.
2. **Azure Virtual WAN** — experimental: vWAN hub with VPN site to AWS.
3. **AWS Transit Gateway** — experimental: TGW as the AWS-side hub for multi-VPC + cross-cloud.

ExpressRoute and Direct Connect are explicitly **out of scope** (cost).

## Subagent usage

Use the matching specialized agent when the task fits:

- `code-reviewer` — review diffs for correctness, style, hidden bugs
- `security-reviewer` — review for IAM over-permissioning, exposed secrets, public-by-default resources, NSG/SG holes
- `terraform-reviewer` — review HCL for state safety, provider version pinning, lifecycle issues, drift risk
- `aws-expert` — AWS service guidance, especially networking and IAM
- `azure-expert` — Azure service guidance (light use — owner is the expert here)

## Workflow expectations

- Before any non-trivial change: state the plan, get user agreement, then implement.
- After scaffolding any cloud resource: write/update its reference architecture doc in the same PR.
- Before declaring a lab complete: confirm `destroy.sh` works and is idempotent.
- Cost-impact statement is required on any PR that adds a billable resource.
