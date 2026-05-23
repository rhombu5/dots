---
name: check-usage
description: Use when the user asks about their Claude subscription usage, credit balance, budget remaining, account state, or anything in that space — e.g. "what's my usage?", "how much credit do I have?", "am I close to my limit?", "check my budget", "how much have I used?". Runs Claude Code's `/usage` slash command via a stream-json subprocess and reports the result. Works in any session because /usage is account-level, not session-scoped, so the data is real and current regardless of where you're running.
---

# check-usage — surface claude `/usage` data without a TUI

The `/usage` slash command is normally only reachable in the interactive Claude Code TUI. But `claude --print --verbose --input-format stream-json --output-format stream-json` accepts slash commands via stdin and emits the response on stdout. `/usage` is account-level (tied to authentication, not session), so any subprocess with the same credentials returns the current user's actual usage data.

## How to run it

```sh
printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/usage"}]}}' \
  | claude --print --verbose --input-format stream-json --output-format stream-json \
  | jq -r 'select(.type == "assistant") | .message.content[0].text'
```

That's it. The `jq` extracts the assistant event's text — the verbatim `/usage` output. Pipe the captured stdout to the user as-is. Don't rephrase, don't summarize unless asked — it's a status report whose exact text is the value.

## Gotchas

- **Stdin must be a pipe**, not a regular file — `claude < file.json` silently emits nothing and exits 0. The `printf | claude` form above is correct.
- **`--verbose` is required** alongside `--output-format stream-json`; claude refuses the combination otherwise.
- The `assistant` event has `"model": "<synthetic>"` and `num_turns: 0` — that's expected for any slash command (the command runs locally, no LLM invocation). Don't mistake it for an error.
- If the user wants to inspect raw events instead of just the text, drop the trailing `jq` pipe.
