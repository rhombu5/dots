---
name: correction
description: Use when Tom corrects *how you responded* — the form/interaction of a reply, not its task-correctness. The tell is "you should have …", "that was an overexplanation", "you didn't need to X", "too verbose", or any critique aimed at response style rather than content. Logs the correction with full context (situation, what you said, why you thought it was warranted, the correction, the fix) to ~/.claude/response-corrections.md, accumulating examples toward a future targeted rule. Also invoked directly as /correction.
---

# correction — log a response-form correction toward a future rule

Tom is collecting examples of corrections to *how I respond* (form and interaction, **not** task-correctness) so a targeted rule can be synthesized once there's enough coverage. This skill captures one correction — richly enough that a future reader can tell the corrected case apart from the justified responses that never get logged.

## When this fires

- Tom explicitly invokes `/correction [text]`.
- Tom critiques the *form* of a response mid-conversation. Strongest tell: **"you should have …"** ("that was an overexplanation, you should have said X"; "you didn't need to Y"; "too verbose"). When I notice this and he hasn't invoked the skill, I run it myself — then apply the fix for the rest of the session.

**Not** this skill: corrections to task *correctness* (a wrong answer, a real bug, a misread requirement). Those are normal work, not response-form data.

## What to capture

I have the full conversation in context — reconstruct the entry from it; don't make Tom restate what I can already see. Append one entry to the log using this template:

```
## <YYYY-MM-DD> — <tentative-category>

- **Situation:** <what Tom asked / what we were doing — the context that prompted the response>
- **What I did:** <the offending response, or the specific part of it — quote or tight paraphrase>
- **Why I thought it was warranted:** <my rationale at the time — the specific cue I read as "this needs explaining / doing">
- **Correction:** <Tom's words, verbatim where possible>
- **Should have:** <the corrected behavior>
```

The **"Why I thought it was warranted"** field is load-bearing and the whole point of the exercise. Only *corrected* cases ever get logged — the justified responses that drew no complaint never do — so the discriminating signal for the future rule lives in the contrast between *why I thought it was warranted* and *why it actually wasn't*. A vague rationale ("seemed helpful") is a wasted entry: name the **specific cue** I misread.

Pick `<tentative-category>` as a short kebab slug (`over-explaining`, `unsolicited-options`, `asked-instead-of-acted`, `narrated-the-obvious`, …). **Reuse an existing category slug** from the log when the correction fits one — consistent slugs are what let me count "~3+ in a category" at synthesis time.

## Where and how to write it

The log is chezmoi-managed. Edit the **source**, not the live copy — a live-only append gets clobbered by the next `chezmoi apply`:

1. Append the entry to `~/src/dots@rhombu5/home/dot_claude/response-corrections.md` (Read it first; append at the end, after existing entries).
2. `chezmoi apply ~/.claude/response-corrections.md` — sync live ← source. Verify `chezmoi diff ~/.claude/response-corrections.md` is empty.
3. Commit + push the dots repo, atomically, as Tom (no Claude attribution — see `~/.claude/CLAUDE.md`). If the non-interactive shell lacks the SSH agent, prepend `SSH_AUTH_SOCK=$HOME/.bitwarden-ssh-agent.sock` to the git push (per `~/.claude/CLAUDE.git.md`). Message shape: `docs(claude): log response correction — <category>`.

Keep the user-facing output terse: one confirmation line (`logged — <category>`), no essay. Then carry the fix forward for the rest of the session.

## Synthesis

When a category reaches **~3+ entries**, offer to draft a targeted rule from the pattern and add it to `~/.claude/CLAUDE.md`. **Don't auto-write the rule** — propose it. The whole reason for collecting is that the rule wasn't describable up front, so Tom validates the synthesis before it lands.
