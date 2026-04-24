# claude-code-kimi-agent

**English** | [简体中文](README_zh.md)

A [Claude Code](https://docs.claude.com/en/docs/claude-code) subagent that delegates self-contained exploration / code-reading / debugging tasks to the local [Kimi CLI](https://github.com/MoonshotAI/kimi-cli) (Moonshot AI). Read-only by default — enforced at Kimi's tool-dispatch layer, not by prompt-level trust.

## Why

Claude Code can already delegate to third-party CLIs — the `codex-rescue` subagent does this for OpenAI's Codex CLI. This project gives you the same pattern for **Kimi**, with a different training lineage (Moonshot, not OpenAI) for a genuinely independent second opinion, and with a locked-down default that can only read.

Where each tool fits:

| | Execution | Can read files | Can write/exec |
|---|---|:---:|:---:|
| `codex-rescue` (OpenAI)       | local CLI   | ✅ | ✅ (can write) |
| **`kimi-agent` (this repo)**  | **local CLI** | **✅** | **❌ (OS-level read-only)** |
| Kimi MCP (`kimi_analyze`)     | remote API  | ❌ (prompt must carry content) | ❌ |
| DeepSeek MCP (`deepseek_ask`) | remote API  | ❌ (prompt must carry content) | ❌ |

Use `kimi-agent` when you want Kimi to explore the repo itself — instead of you pre-loading context into a prompt — but you don't want it to mutate anything.

## How "read-only" is enforced

Kimi CLI loads an agent definition via `--agent-file`. The YAML shipped in this repo extends the default agent but excludes every write-capable tool:

```yaml
version: 1
agent:
  extend: default
  exclude_tools:
    - "kimi_cli.tools.file:WriteFile"
    - "kimi_cli.tools.file:StrReplaceFile"
    - "kimi_cli.tools.shell:Shell"
```

Kimi sees only `ReadFile` / `ReadMediaFile` / `Glob` / `Grep` (and web-search / etc.) at dispatch time. There is no prompt to jailbreak — the write tools don't exist in this session. Verified behavior: when asked to create a file, Kimi responds that its toolset "does not include Shell or WriteFile," and no file appears on disk.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (the CLI / IDE extension)
- [Kimi CLI](https://github.com/MoonshotAI/kimi-cli) (installed, authenticated via `kimi login`)
- `gtimeout` (macOS: `brew install coreutils`) **or** `timeout` (Linux: usually in coreutils by default)
- Bash (macOS/Linux default shell works)

## Install

```bash
git clone https://github.com/zcyyyds-test/claude-code-kimi-agent.git ~/code/claude-code-kimi-agent
cd ~/code/claude-code-kimi-agent
./install.sh
```

`install.sh` is idempotent. It verifies dependencies, then symlinks:
- `agents/kimi-agent.md` → `~/.claude/agents/kimi-agent.md`
- `agents/kimi-agent.read-only.yaml` → `~/.claude/agents/kimi-agent.read-only.yaml`

Restart Claude Code after install so it picks up the new subagent.

## Usage

Inside Claude Code, delegate to Kimi with the `Agent` tool:

```
Agent(
  subagent_type="kimi-agent",
  prompt="Read src/auth/session.ts and explain the refresh-token rotation flow. Focus on race conditions.",
  run_in_background=true,
)
```

Or let the main Claude thread pick it up automatically when it sees a task that matches the selection guidance in `agents/kimi-agent.md`.

The subagent constructs exactly one Bash call, roughly:

```bash
gtimeout 600 bash -c '... kimi --quiet --agent-file <yaml> -p "$1" -w "$2" 2>&1' _ '<PROMPT>' '<WORK_DIR>'
```

Notes:
- Prompts are passed as positional arguments — safe from shell expansion of `$VAR`, `$(cmd)`, backticks, newlines, and quotes.
- Synchronous, hard-capped at 10 minutes. No background mode inside Kimi itself.
- Failure modes (missing binary, timeout, missing API key) surface the merged stdout+stderr to the main thread verbatim.

## Safety tests performed

| Scenario | Result |
|---|---|
| Read-only: ask Kimi to create `/tmp/kimi-write-test.txt` | Kimi refuses, explains tools unavailable; file does not exist on disk |
| Injection: prompt contains `$HOME`, `$(whoami)`, backticks, quotes, newlines | All preserved as literal text — outer shell never expands |
| Fail-fast: kimi binary missing from `PATH` | Returns exit 127 in 0s with clear error |
| Timeout: task exceeds 10 minutes | `gtimeout` returns exit 124 |

## Acknowledgments

The subagent structure (thin forwarding wrapper, `Bash`-only tool, selection-guidance layout) is inspired by OpenAI's [`codex-rescue`](https://github.com/openai/codex-plugin-cc) subagent in the Codex Claude Code plugin. This project applies the same pattern to a different CLI (Kimi) with a different risk posture (read-only by default).

## License

[MIT](LICENSE).

## Disclaimer

Not affiliated with Moonshot AI, Anthropic, or OpenAI. "Kimi" and "Claude Code" are trademarks of their respective owners. This project is a third-party adapter that calls each vendor's officially documented CLI / API surface.
