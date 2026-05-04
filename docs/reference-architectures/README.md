# Reference architectures

**These docs are the source of truth for every AWS and Azure resource we build in this repo.**

Terraform code and live cloud state are *implementations* of what's documented here. If code and doc disagree, the doc is canonical — either the code is wrong, or the doc needs to be updated deliberately as part of the change.

## Structure

```
reference-architectures/
├── aws/
│   ├── networking/         VPC, subnets, route tables, IGW, NAT, TGW, VGW
│   ├── identity/           IAM users, roles, policies, Identity Center
│   ├── compute/            EC2, Lambda, ECS, EKS
│   ├── storage/            S3, EBS, EFS
│   └── observability/      CloudWatch, CloudTrail
├── azure/
│   ├── networking/         VNet, subnets, NSG, route tables, VPN GW, vWAN
│   ├── identity/           AAD, RBAC, Managed Identities
│   ├── compute/            VM, Function, AKS, Container Apps
│   ├── storage/            Storage Account, Managed Disks
│   └── observability/      Log Analytics, Azure Monitor
├── cross-cloud/            Connectivity patterns spanning both clouds
│   ├── vpn-site-to-site/
│   ├── azure-vwan-aws-vpn/
│   └── aws-tgw-azure-vpn/
└── claude/                 Claude Code config (operating guide, subagents,
                            hooks, settings, routines, templates) — uses an
                            adapted section template, see claude/README.md
```

## Required sections per doc

Every reference doc must include:

1. **Purpose** — what this resource is and when to use it.
2. **Diagram** — ASCII or linked image showing topology.
3. **Components** — table of every resource created, with type, name pattern, and role.
4. **Networking** — IP ranges, routing, peering, exposure.
5. **Identity** — IAM/RBAC scopes used and granted.
6. **Cost** — hourly/monthly estimate, with the dominant cost drivers called out.
7. **Teardown** — anything special required for clean destroy (force_destroy flags, soft-delete bypass, etc.).
8. **Cross-cloud notes** (where applicable) — equivalent resource in the other cloud.
9. **Gotchas** — non-obvious failure modes.
10. **Related Terraform** — path(s) under `aws/`, `azure/`, or `labs/`.

## Naming

- Service-level docs: `aws/networking/vpc.md`, `azure/networking/vnet.md`.
- Pattern docs: `cross-cloud/vpn-site-to-site/README.md` (a directory with diagrams as siblings).
- Use kebab-case filenames.
