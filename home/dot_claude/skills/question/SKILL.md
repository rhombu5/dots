---
name: question
description: Surfaces the single most pressing open question or discussion item the session is holding for the owner, presented /explain-style. Triggered by /question, and by the owner saying "ask me a question" (or a close variant).
---

# Question — what do you need from me?

Pick the **one** most pressing open question, pending decision, or discussion item currently
waiting on the owner, and present it.

## Picking the item

Scan everything the session is holding open — the task list, findings/decision files, anything
mentally parked for "when the owner's back" — and rank:

1. **Blocking beats important** — an item actively stalling in-flight work outranks everything else.
2. **Leverage breaks ties** — the answer that unblocks the most downstream work wins.
3. **Age breaks remaining ties** — oldest first.

## Presenting it

Run the `/explain` skill on the chosen item — plain-language prose plus a concrete code snippet
wherever code makes it checkable. Additionally:

- **Lead with the question itself** — one sentence, before any context.
- Give only the context needed to decide; no history tour.
- If it's a fork, name the options and give a recommendation with the reason.
- Close with what the answer unblocks.

## One per invocation

Exactly one item. Present it, stop, wait for the answer. The next `/question` gets the next item.

## An unanswered item gates the queue

If `/question` arrives while the previously presented item is still awaiting the owner's explicit
response, do NOT advance. Re-present the pending question in one or two compact lines and require
an answer before surfacing anything new. An explicit "skip" or "defer" counts as a response and
releases the queue; silence or an unrelated reply does not.

An item that has DISSOLVED since it was presented — mooted by a later ruling, superseded by the
discussion it sparked, or otherwise no longer a decision anyone needs to make — is an implicit
no-op: it never gates. Note the dissolution in one line and advance.

## Nothing pending?

Say so in one line and stop — don't invent a question.
