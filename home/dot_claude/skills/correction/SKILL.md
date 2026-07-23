---
name: correction
description: Use when Tom corrects me for over-explaining — saying more than the moment warranted (verbosity, re-explaining something already understood, unsolicited analysis or output, a treatise where yes/no or A-or-B would do). The tell is "a yes would've sufficed", "you should have just said X", "too verbose", "you didn't need to Y", "end the word salads". Other response-form critiques (omissions, ordering, process, tone) are out of scope — handled inline, not logged. Logs the correction with full context (situation, what you said, why you thought it was warranted, the correction, the fix) to ~/.claude/response-corrections.md, accumulating examples toward a future anti-verbosity rule. Also invoked directly as /correction.
---

# correction — log an over-explaining correction toward a future rule

Tom is collecting examples of ONE failure mode — **over-explaining**: using more tokens than the moment warranted (verbosity; re-explaining something already understood; dumping analysis or output he didn't ask for; answering a yes/no or A-or-B question with a treatise). This is the **only** thing the log tracks, toward a targeted anti-verbosity rule — corrections about any *other* aspect of how I respond (omissions, ordering, process, tone) get handled inline, not logged. This skill captures one correction — richly enough that a future reader can tell the corrected case apart from the justified responses that never get logged.

## When this fires

- Tom explicitly invokes `/correction [text]`.
- Tom critiques me for saying too much — spending tokens he didn't want spent — mid-conversation. Tells: **"a yes would've sufficed"**, "you should have just said X", "too verbose", "you didn't need to Y", "end the word salads". When I notice this and he hasn't invoked the skill, I run it myself — then apply the fix for the rest of the session.

**Not** this skill: corrections to task *correctness* (a wrong answer, a real bug, a misread requirement), or any critique that isn't "you said too much" — including saying too *little*, omissions, ordering, process, tone. Those are handled inline and moved on from, not logged here.

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

When a category reaches **~3+ entries**, draft a targeted rule from the pattern and present it directly — don't ask first whether to draft one. **Still don't auto-write it to `~/.claude/CLAUDE.md`** — show the drafted rule for Tom to validate before it lands. The whole reason for collecting is that the rule wasn't describable up front, so the draft itself is what gets reviewed, not a prior yes/no about whether to attempt one.
