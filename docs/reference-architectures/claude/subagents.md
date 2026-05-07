# Claude subagents

Source-of-truth doc for the five specialized agents under `.claude/agents/`. Each subagent runs in its own context window with its own tool set and its own prompt, and is invoked from the main session via the `Agent` tool.

## 1. Purpose

Subagents exist to:

1. **Protect the main context window** — long file reads, web searches, and exhaustive grep sweeps happen inside the subagent and only the summary returns.
2. **Specialize behavior** — a reviewer agent has a sharper review prompt than the main session would naturally adopt mid-task.
3. **Parallelize independent work** — multiple subagents can run concurrently when the main session needs answers from independent sources.

## 2. Components

| Agent | File | Tools allowed | Primary use |
|---|---|---|---|
| `aws-expert` | `agents/aws-expert.md` | Read, Grep, Glob, Bash, WebFetch, WebSearch | AWS service guidance — networking, IAM, cross-cloud connectivity. Always frames answers via Azure analogues. |
| `azure-expert` | `agents/azure-expert.md` | Read, Grep, Glob, Bash, WebFetch, WebSearch | Light use only — owner is the Azure expert. Reserved for cross-cloud edge cases, vWAN specifics, and Azure-side design validation. |
| `code-reviewer` | `agents/code-reviewer.md` | Read, Grep, Glob, Bash | Diff review for correctness, hidden bugs, repo conventions. Output grouped Blocker / Should fix / Nit. |
| `security-reviewer` | `agents/security-reviewer.md` | Read, Grep, Glob, Bash | IAM/RBAC scoping, public exposure, secrets in git, SG/NSG holes. Output grouped Critical / High / Medium / Info. |
| `terraform-reviewer` | `agents/terraform-reviewer.md` | Read, Grep, Glob, Bash | HCL-specific: provider pins, state safety, lifecycle, drift, idempotency. Output grouped Blocker / Should fix / Nit. |

All five live as Markdown files with YAML frontmatter (`name`, `description`, `tools`). The body is the system prompt.

## 3. Trigger / scope

Two ways an agent runs:

1. **Main session invokes via `Agent` tool**, choosing `subagent_type` based on the task. The matching of task → subagent is judgment-driven; the descriptions in each agent's frontmatter (and the "Subagent usage" section of [`operating-guide.md`](operating-guide.md)) are what the main session reads to decide.
2. **User explicitly requests** — e.g., "review this with security-reviewer."

When to invoke each, in practice:

- After non-trivial code changes (before opening a PR): `code-reviewer` + `terraform-reviewer` (in parallel — they don't overlap).
- Before merging anything that touches IAM, networking, secrets, or public resources: `security-reviewer`.
- When designing or debugging an AWS service: `aws-expert`.
- When the user wants a second opinion on an Azure design choice: `azure-expert` (rare).

## 4. Behavior contract

Each agent's frontmatter `description` is what the main session keys off when picking. The body of each file is what the *agent* runs as its system prompt. Both are load-bearing — see Gotchas.

Common output discipline across the three reviewers: severity-grouped findings with `path:line — issue — fix`. If clean, terse "LGTM" / "No issues found" / "Terraform LGTM" — no padding. The `code-reviewer.md` and `security-reviewer.md` files explicitly say so.

Repo-specific guardrails baked into the agents:

- `aws-expert` and `azure-expert` both lead any resource recommendation with cost.
- `aws-expert` refuses Direct Connect; both refuse anything with a heavy standing charge unless asked.
- `terraform-reviewer` forbids `lifecycle.prevent_destroy` (incompatible with daily teardown) and remote backends (project decision is local state).
- `security-reviewer` blocks SSH from `0.0.0.0/0` outright — require known-IP variable or SSM/Bastion.

## 5. Cost / blast radius

Non-monetary. Three failure modes:

- **Wrong agent picked:** `azure-expert` for a basic Azure question wastes tokens and slows the response. The "use sparingly" note in `azure-expert.md` exists to make the main session de-prefer it.
- **Agent prompt drifts from project rules:** if `terraform-reviewer.md` no longer mentions the local-state rule, real PRs slip through with remote backend blocks.
- **Reviewer agent is verbose:** the explicit "no padding" instructions are the antidote. If a reviewer starts producing wall-of-text reports, the prompt has drifted.

## 6. Gotchas

- **Frontmatter `description` is what the main session matches against** when choosing an agent. If you rename or reword it, the main session may stop picking the agent for tasks it should handle. Keep `description` aligned with the actual scope.
- **Subagents don't see the main session's conversation.** Brief them like a colleague who just walked in: paths, line numbers, what to assess, what to skip. "Based on the discussion above, fix it" will not work.
- **Subagents inherit no project memory.** If a behavior depends on something stored in `~/.claude/.../memory/`, the subagent won't have it — pass it explicitly in the prompt.
- **Tool list is enforced.** A subagent without `Bash` cannot run `terraform validate`. Adding tools to the frontmatter expands what the agent can do, removing them constrains it. Match the tool set to the job.
- **`azure-expert` is intentionally conservative.** Don't expand its scope to compensate for the main session being slow on Azure — the main session is the expert here.

## 7. Related files

- `.claude/agents/aws-expert.md`
- `.claude/agents/azure-expert.md`
- `.claude/agents/code-reviewer.md`
- `.claude/agents/security-reviewer.md`
- `.claude/agents/terraform-reviewer.md`
- [`operating-guide.md`](operating-guide.md) — repo-wide rules these agents enforce
- [`routines.md`](routines.md) — workflows that call these agents (review-before-PR, etc.)
