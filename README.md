# cross-cloud-labs

Hands-on lab repo for AWS learning + Azure↔AWS cross-cloud connectivity.

## Goals

- Get fluent with AWS (owner is an Azure expert).
- Build cross-cloud connectivity patterns: site-to-site VPN first, then Azure Virtual WAN and AWS Transit Gateway experiments.
- Stay inside a $100 AWS promo credit and minimal Azure spend by tearing everything down nightly.

## Hard rules

1. **Daily teardown.** Every cloud resource must be destroyable on demand. Run `./teardown-all.sh` at end of day (or schedule it locally).
2. **Cost first.** Every PR that adds a billable resource must state its hourly/monthly cost. ExpressRoute and Direct Connect are out of scope.
3. **Local Terraform state.** No remote backends. State files are gitignored.
4. **Local `.env` auth only.** Credentials live in `.env` (gitignored). See `.env.example`.
5. **Branch + PR workflow.** Never push to `main`.
6. **Reference architecture docs are source of truth.** Every resource we build gets a doc under `docs/reference-architectures/<cloud>/`.

## Repo layout

```
.claude/                       Claude Code config (CLAUDE.md, agents, settings)
.github/                       GitHub config
aws/                           AWS-only Terraform building blocks
azure/                         Azure-only Terraform building blocks
labs/                          Cross-cloud labs — each independently apply/destroy-able
docs/
  reference-architectures/     Source of truth for every resource we build
    aws/
    azure/
  study-guides/                PDFs/PNGs (cloud product mapping, monitoring, databases)
teardown-all.sh                Walks all labs and destroys
.env.example                   Template for local .env
```

## Getting started

```bash
# 1. Clone & enter
git clone <repo> && cd cross-cloud-labs

# 2. Set up credentials
cp .env.example .env
$EDITOR .env   # fill in AWS keys + Azure SP

# 3. Pick a lab
cd labs/<lab-name>

# 4. Apply
set -a && source ../../.env && set +a
terraform init
terraform plan
terraform apply

# 5. Tear down (end of day, every day)
cd ../..
./teardown-all.sh
```

## Connectivity roadmap

| # | Lab | Status |
|---|-----|--------|
| 1 | Site-to-site IPSec VPN (Azure VPN GW ↔ AWS VGW/TGW) | not started |
| 2 | Azure Virtual WAN with VPN site to AWS | not started |
| 3 | AWS Transit Gateway as multi-VPC + cross-cloud hub | not started |

## Reference architectures

See [`docs/reference-architectures/`](docs/reference-architectures/). Every resource we deploy must have a doc here. If code and doc disagree, the doc wins (or update the doc deliberately).

## Study guides

Reference material (cloud product mapping, monitoring cheat sheets, cloud databases overview) lives in [`docs/study-guides/`](docs/study-guides/).
