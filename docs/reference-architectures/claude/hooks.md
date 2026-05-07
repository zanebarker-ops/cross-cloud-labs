# Claude Code hooks

Source-of-truth doc for `.claude/hooks/` and the `hooks` block in `.claude/settings.json`.

## 1. Purpose

Hooks let the Claude Code harness run a shell command at well-defined points in the tool-call lifecycle (PreToolUse, PostToolUse, etc.). The harness — not Claude — decides whether to allow the tool call based on the hook's exit code.

In this repo, hooks are used to enforce project rules that cannot be expressed as static permission patterns in `settings.json` because the rule depends on **runtime state** (which branch is checked out, whether a file exists, what's in it).

## 2. Components

| File | Event | Matcher | What it does |
|---|---|---|---|
| `hooks/block-main-write.sh` | `PreToolUse` | `Bash` | Blocks `git commit` and `git push` when the current branch is `main` or `master` |

The `settings.json` `hooks` block wires the script in:

```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/block-main-write.sh" }
      ]
    }
  ]
}
```

## 3. Trigger / scope

`block-main-write.sh` fires before **every** Bash tool call (matcher: `Bash`). The script itself short-circuits early if the command isn't `git commit` or `git push`, so the per-call overhead for any other Bash command is one process invocation + one `jq` parse.

The matcher is intentionally broad (`Bash`, not a more specific pattern) so the harness can't be tricked by command obfuscation (e.g., `bash -c 'git push'`, `eval "git push"`). The script does its own command-shape check internally.

## 4. Behavior contract

1. Hook reads stdin as JSON (`tool_input.command`, `cwd`).
2. If the command doesn't word-boundary match `git commit` or `git push` at the start of any segment, exit 0 (allow).
3. Otherwise, resolve the working tree from `cwd` (or `$PWD`) and read `git branch --show-current`.
4. If the branch is `main` or `master`, exit 2 with a stderr message explaining the block. Exit 2 tells the harness to refuse the tool call and surface the message to Claude.
5. Otherwise, exit 0.

The script uses `set -euo pipefail` and fails closed: if `jq` isn't installed, the hook exits 1 (fail), which the harness treats as an error — the tool call does **not** proceed. This is deliberate. Better to break than to silently allow.

## 5. Cost / blast radius

Non-monetary. Failure modes:

- **Hook silently broken:** `jq` missing, script not executable, syntax error. The harness will surface the error rather than allow the call (fail-closed by design), so the Claude session sees the failure immediately rather than discovering a push to main hours later.
- **Hook overzealous:** false-positive on a command that contains `git commit` or `git push` as a substring of something else. The word-boundary regex (`(^|[;&|[:space:]])git[[:space:]]+(commit|push)([[:space:]]|$)`) handles common shell separators but not every conceivable case (e.g., backticks, `$()`).
- **Detached HEAD:** `git branch --show-current` returns empty, the case statement doesn't match, hook allows. This is intentional — detached HEAD is unusual in this repo, but it's not the same as "you're on main."

## 6. Gotchas

- **The hook is a backstop, not the only line of defense.** `settings.json` `deny` already blocks `git push origin main*` and `git push --force origin main*`. Those handle the explicit-target case. The hook handles the bare-`git push` case where the current branch's tracking ref is what gets pushed — that's not pattern-matchable from the literal command string.
- **The hook needs `$CLAUDE_PROJECT_DIR` resolved by the harness** at hook-config-load time. If you copy the `settings.json` snippet to a different repo, the path needs to be valid there too.
- **Worktree-aware:** the hook uses the tool's `cwd` to resolve which working tree to read the branch from. So a Bash call run from the Azure worktree (`cross-cloud-labs-azure`) checks that worktree's HEAD, not the original clone's. This is correct — each worktree has its own checked-out branch.
- **Hooks run for every Bash call.** Keep them fast. The current script is one fork + one `jq` parse for non-git calls (~5 ms). If a heavier hook gets added, the cumulative latency on a session with hundreds of Bash calls becomes noticeable.

## 7. Related files

- `.claude/hooks/block-main-write.sh` — the hook script
- `.claude/settings.json` — the `hooks.PreToolUse[]` block that registers it
- [`operating-guide.md`](operating-guide.md) — hard rule #5 ("Never push to `main`") that this hook enforces
- [`settings.md`](settings.md) — the static `deny` patterns that complement this hook
