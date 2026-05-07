# Claude Code settings (`settings.json`)

Source-of-truth doc for `.claude/settings.json` — the project-level Claude Code configuration: permission allow/ask/deny lists, environment variables, hook registrations.

## 1. Purpose

`settings.json` is the harness's static permission policy for tool calls in this project. It controls which Bash patterns Claude can run without prompting, which require user approval, and which are forbidden outright. It also wires up hooks (see [`hooks.md`](hooks.md)) and exports project-level env vars to every tool execution.

## 2. Components

### Permission tiers

| Tier | Meaning | Examples in this repo |
|---|---|---|
| `allow` | Tool runs immediately, no prompt | Read-only Terraform (`init`, `validate`, `plan`, `show`, `output`, `state list`), read-only AWS/Azure CLI (`sts get-caller-identity`, `ec2 describe-*`, `az account show`), read-only git (`status`, `diff`, `log`, `branch`), branch ops (`checkout`, `add`, `commit`, `push origin <non-main>`) |
| `ask` | Tool prompts the user before running | State-changing Terraform (`apply`, `destroy`, `import`, `state rm`, `state mv`), all AWS IAM `create/delete/attach/put`, all AWS EC2 `create/delete/terminate`, Azure RG `create/delete`, Azure SP `create/delete`, `git push --force`, `gh pr merge` |
| `deny` | Tool refused outright | `rm -rf /*`, `git push origin main*`, `git push --force origin main*`, `terraform destroy --auto-approve --target=*`, `Read(./.env)`, `Read(./**/.env)` |

### Environment variables

| Var | Value | Effect |
|---|---|---|
| `TF_IN_AUTOMATION` | `1` | Tells Terraform it's running non-interactively — suppresses "did you mean...?" suggestions and other prompt-shaped output. Reduces noise in tool result captures. |

### Hook registrations

See [`hooks.md`](hooks.md). Currently one entry: `PreToolUse` matcher `Bash` runs `block-main-write.sh`.

## 3. Trigger / scope

- Loaded by the harness when a session opens with this project as cwd.
- Stacks beneath user-level (`~/.claude/settings.json`) and personal-project (`.claude/settings.local.json`, gitignored) settings — project settings here are the team baseline.
- Permission rules are matched against the tool input string with prefix glob semantics; the first matching rule wins. `deny` evaluates before `allow` for safety.

## 4. Behavior contract

The intent of the three tiers in this repo:

- **`allow` is "read-only or local-state-only and reversible."** Every entry is something a curious Claude can run without surprising the user — no cloud writes, no destructive git, no money spent.
- **`ask` is "state change with consequences."** `terraform apply` makes infra. `gh pr merge` is irreversible without effort. The user is the final gate.
- **`deny` is "no possible context where this is right."** `rm -rf /*` has no use case here. `git push origin main*` violates hard rule #5. Reading `.env` exposes credentials.

The `Read(./.env)` and `Read(./**/.env)` denials are why Claude cannot inspect credential files even when the user asks — the user must run the command themselves (e.g., via the `!` prefix in the prompt). This is a deliberate friction point.

## 5. Cost / blast radius

Non-monetary, but the cost of a bad rule here is real:

- **Too permissive `allow`:** Claude runs something destructive without prompting (e.g., adding `Bash(aws ec2 *)` would let it terminate instances silently).
- **Too restrictive `allow`:** Claude prompts on every `git status`, slowing the session to a crawl. Friction → users disable settings → no protection.
- **Missing `deny` for known-bad pattern:** the `git push origin main` deny is what stops an accidental main-push cold. The hook is a backstop because pattern-only deny can't catch bare `git push` (resolves to current branch at runtime).
- **`ask` list shrinking over time:** if convenience-creep moves things from `ask` → `allow`, suddenly `terraform destroy` runs without confirmation and a lab vanishes mid-investigation.

## 6. Gotchas

- **Pattern semantics:** rules use Claude Code's permission glob semantics, not full shell glob. `Bash(terraform plan*)` matches the literal start of the command string. Verify edge cases by reading the [Claude Code permissions docs](https://docs.claude.com/en/docs/claude-code/settings#permissions) before relying on a clever pattern.
- **`deny` beats `allow`:** order in the JSON doesn't matter; precedence is by tier. `Bash(git push origin main*)` in `deny` overrides `Bash(git push origin*)` in `allow`.
- **Bare `git push` is not pattern-matchable.** It resolves to the current branch's tracking ref at runtime, not a literal `origin main`. The `deny` list cannot catch it. The `block-main-write.sh` hook catches it instead by reading the live branch.
- **`Read(./.env)` does not block other tools** — it only blocks the `Read` tool. A `Bash(cat .env)` would still match `allow`/`ask`/`deny` for the Bash tool, not the Read deny. Currently no Bash pattern allows reading `.env` because `cat` is not in the `allow` list, but adding broad `Bash(cat *)` would silently bypass the `Read` deny. Don't add it.
- **`TF_IN_AUTOMATION` changes Terraform output formatting slightly.** If a tool result parser depends on Terraform's interactive-mode output, this var will surprise it.
- **`settings.json` is checked in; `settings.local.json` is not.** Personal overrides go in `.local`. Don't put credentials, machine-specific paths, or per-user permissions in the checked-in file.

## 7. Related files

- `.claude/settings.json` — the file this doc covers
- [`hooks.md`](hooks.md) — what the `hooks` block wires up
- [`operating-guide.md`](operating-guide.md) — the rules these permissions encode
- [`subagents.md`](subagents.md) — subagents inherit the same permission model
