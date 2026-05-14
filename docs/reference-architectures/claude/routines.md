# Recurring workflows ("routines")

Source-of-truth doc for the recurring workflows the project expects every change to follow. These are not configured anywhere as a single artifact — they emerge from the interaction of `CLAUDE.md` hard rules, `settings.json` permission tiers, hooks, and the reviewer subagents.

This doc names them so they can be referenced explicitly ("follow the phased-apply routine").

## 1. Purpose

A "routine" here means an expected recurring workflow — the same sequence of steps the user expects every time a particular kind of work happens. Naming and documenting them makes it cheaper to invoke ("run the cost-impact routine before opening the PR") and easier to onboard a new contributor (human or AI).

If a routine ever becomes a scheduled remote agent (via the `/schedule` skill), it gets a "Schedule" subsection on its entry below with the cron spec. Until then, every routine here is **on-demand or workflow-triggered**, not cron-driven.

## 2. The routines

### 2.1 Plan → confirm → apply

**Trigger:** any non-trivial change (cloud resource creation/modification, cross-cloud lab work, multi-file refactor).

**Steps:**
1. State the plan in conversation. Include affected files, expected new/changed/destroyed resources, and any cost impact.
2. Wait for explicit user agreement before any tool calls that mutate state.
3. Run the plan stage non-mutatingly first (`terraform plan -out=...`).
4. Show the plan summary in chat.
5. Apply only after user confirms ("go", "apply", explicit yes).

**Why:** matches the `ask` permission tier — `terraform apply` and `destroy` already prompt — and prevents Claude from racing ahead into a state change the user didn't sign off on.

**Enforcement:**
- `settings.json` `ask` tier on `terraform apply`, `terraform destroy`, `aws ec2 create-*`, `aws iam create-*`, etc.
- `CLAUDE.md` "Workflow expectations": "Before any non-trivial change: state the plan, get user agreement, then implement."

### 2.2 Phased cross-cloud apply

**Trigger:** any cross-cloud lab where one cloud's outputs are required as another cloud's inputs (the VPN site-to-site lab is the canonical case).

**Steps:**
1. **Phase 1 — Side A apply.** Apply only the resources that don't depend on the other side. Capture outputs (public IPs, ASNs, CIDRs, PSKs).
2. **Phase 2 — Side B apply.** Paste Side A's outputs into Side B's tfvars (gitignored). Apply Side B fully. Capture Side B's outputs.
3. **Phase 3 — Side A apply (round 2).** Paste Side B's outputs into Side A's tfvars. Flip the side-A `create_connection`-style flag to true and re-apply.

**Why:** local Terraform state on both sides means there's no shared state to wire the two together automatically. Manual outputs-as-inputs paste is the workflow.

**Enforcement:**
- Encoded in lab READMEs (e.g., `azure/labs/vpn-site-to-site/README.md` documents the three phases).
- Variables on each side are split into "phase 1 inputs" vs "phase 3 inputs" with the gating boolean (`create_connection`).
- Cross-cloud ref-arch doc (`docs/reference-architectures/cross-cloud/vpn-site-to-site/README.md`) is the source of truth for which outputs map to which inputs.

### 2.3 Daily teardown

**Trigger:** end of working day, or when stepping away long enough to risk forgotten resources.

**Steps:**
1. From repo root, run `./teardown-all.sh` (walks every lab dir and runs its `destroy.sh`).
2. Or, per-lab: `cd <lab-dir> && ./destroy.sh`.
3. Verify in cloud consoles that no orphan resources remain (especially Azure VPN gateways, AWS public IPv4s, AWS VPN connections).

**Why:** $100 AWS credit must last ~6 months. Azure is real money. The dominant standing costs (Azure VPN GW ~$0.19/hr, AWS VPN connection ~$0.05/hr) burn budget overnight.

**Enforcement:**
- `CLAUDE.md` hard rule #1.
- `terraform-reviewer.md` blocks any `lifecycle.prevent_destroy`.
- Every lab ships a `destroy.sh`. Reviewer agents flag PRs that add resources without updating teardown paths.

### 2.4 Branch + PR (never push to main)

**Trigger:** every change.

**Steps:**
1. `git checkout -b <feature-branch-name>` (prefix `aws-*` or `azure-*` per worktree-layout convention if applicable).
2. Commit and push the branch.
3. Open a PR via `gh pr create`.
4. Reviewer agents (see 2.6) run on the diff.
5. Merge via PR — never push to `main` directly.

**Why:** preserves history, gives reviewer agents a diff to inspect, and keeps `main` always-green.

**Enforcement:**
- `CLAUDE.md` hard rule #5.
- `settings.json` `deny` blocks `git push origin main*` and `git push --force origin main*` (literal pattern).
- `block-main-write.sh` hook blocks `git commit` and `git push` from the working tree when HEAD is on `main` or `master` (catches the bare-`git push` case where the deny pattern doesn't match).
- Repo-side: `git pre-push` hook (commit `6770834`) blocks pushes from `main`/`master` even outside Claude Code.

### 2.5 Doc-as-source-of-truth (write/update with the change)

**Trigger:** any PR that adds, removes, or modifies an AWS or Azure resource — or changes how Claude itself is configured.

**Steps:**
1. Identify which ref-arch doc covers the resource (or create it if it's new — `docs/reference-architectures/<cloud>/<category>/<resource>.md`).
2. Update the doc *in the same PR* as the code change. Doc and code ship together.
3. If code and doc disagree mid-PR, fix the doc (or fix the code to match the doc — whichever was correct).

**Why:** the ref-arch docs are the canonical reference. Code without docs rots; docs without code don't exist.

**Enforcement:**
- `CLAUDE.md` hard rule #6.
- `code-reviewer` agent flags resource additions without doc updates.
- This very file is an instance of the routine: the `.claude/` config has these docs because they're part of the source of truth.

### 2.6 Pre-merge review (multi-agent)

**Trigger:** before opening or merging any non-trivial PR.

**Steps (parallel where possible):**
1. **`code-reviewer`** — correctness, hidden bugs, repo conventions, cost surprises, teardown story, style. Output: Blocker / Should fix / Nit.
2. **`terraform-reviewer`** — provider pins, state safety, lifecycle, idempotency. Run for any HCL change. Output: Blocker / Should fix / Nit.
3. **`security-reviewer`** — IAM/RBAC scoping, secrets, public exposure, SG/NSG holes. Run if the diff touches IAM, networking, secrets, or public-facing resources. Output: Critical / High / Medium / Info.

**Why:** specialized reviewers catch class-specific issues the main session would miss while focused on the actual change.

**Enforcement:**
- Subagent prompts (`agents/code-reviewer.md`, `agents/terraform-reviewer.md`, `agents/security-reviewer.md`) enforce the output discipline.
- `operating-guide.md` "Subagent usage" section instructs the main session when to invoke each.

### 2.7 Cost-impact statement on PRs

**Trigger:** any PR that adds a billable resource (cloud or otherwise).

**Steps:**
1. State the new resource's hourly and monthly cost in the PR description.
2. Identify the dominant cost driver.
3. Confirm `destroy.sh` covers the new resource (loop back to 2.3).

**Why:** budget is the #1 constraint. Surprise bills are the #1 risk.

**Enforcement:**
- `CLAUDE.md` "Workflow expectations": "Cost-impact statement is required on any PR that adds a billable resource."
- `aws-expert` and `azure-expert` agent prompts both lead with cost.
- `code-reviewer.md` "Cost surprises" check flags omissions.

### 2.8 Reference-arch refresh after deploy

**Trigger:** after a successful deploy that revealed code-vs-doc drift.

**Steps:**
1. Note the discrepancy (e.g., doc says Premium SSD, code uses Standard_LRS).
2. Determine which is correct (almost always: the working code).
3. Update the ref-arch doc(s) to match. The doc is canonical going forward.
4. Commit the doc update on the same branch as the deploy work, or a follow-up PR if scope is mixed.

**Why:** drift compounds. The first time a doc diverges from reality, fix it.

**Enforcement:**
- `CLAUDE.md` hard rule #6 (last sentence): "If code and doc disagree, the doc is canonical (or update the doc deliberately as part of the change)."

## 3. Cost / blast radius (of the routines themselves)

If a routine drifts:

- **Plan→confirm→apply skipped:** `terraform apply` runs without user sight; surprise resources, surprise spend.
- **Phased cross-cloud apply skipped:** the second-side apply tries to read first-side outputs that aren't pasted, fails, but only after creating partial state. Rollback is manual.
- **Daily teardown skipped:** ~$5/day Azure-side and ~$1/day AWS-side accumulate; over a month, that's the entire AWS credit.
- **Branch+PR skipped:** main breaks for everyone, no review record.
- **Doc-as-source-of-truth skipped:** docs become aspirational fiction within weeks; reviewer agents key off them and emit wrong findings.
- **Pre-merge review skipped:** insecure or non-idempotent code lands.
- **Cost-impact omitted:** budget exhaustion without anyone seeing it coming.
- **Doc refresh skipped:** drift compounds (see above).

## 4. Gotchas

- **Routines are conventions, not contracts.** Most are not enforced by code or hooks — they're enforced by the main session paying attention to `CLAUDE.md` and the reviewer subagents catching omissions. If `CLAUDE.md` drifts, routines silently stop happening.
- **The phased apply routine assumes both sessions are alive.** If one Claude session crashes mid-phase-2, the other session's terraform state still references resources the first side hasn't seen.
- **Daily teardown vs. mid-deploy:** if a deploy is in flight at end-of-day, the routine must wait. Tearing down a partially-applied lab leaves stranded resources that the next apply won't claim.
- **A new routine added here needs `CLAUDE.md` to reference it** — otherwise the main session won't know to follow it on a fresh conversation.

## 5. Related files

- `.claude/CLAUDE.md` — hard rules and workflow expectations these routines instantiate
- `.claude/settings.json` — permission tiers that gate `apply`/`destroy`/`push`
- `.claude/hooks/block-main-write.sh` — hook enforcing routine 2.4
- `.claude/agents/*.md` — reviewer agents that run routine 2.6
- `teardown-all.sh` — entry point for routine 2.3
- `.github/pull_request_template.md` — template that prompts for cost-impact statement (routine 2.7)
- [`operating-guide.md`](operating-guide.md), [`settings.md`](settings.md), [`hooks.md`](hooks.md), [`subagents.md`](subagents.md) — sibling ref-arch docs
