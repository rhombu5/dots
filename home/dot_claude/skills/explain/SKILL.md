---
name: explain
description: Explains a topic one at a time using plain-language prose plus a concrete code snippet. Triggered by /explain (people may also reach for /splain), with the topic passed as the argument.
---

# Explain

Explain the topic using **both** plain-language prose **and** a concrete code snippet — code wherever it would help, not abstract prose alone. Some topics genuinely have no code; for those, prose alone is fine. But whenever a snippet would make the explanation concrete and checkable, reach for it.

- **Prose** says what it does and why, in ordinary words.
- **Code** makes it concrete and checkable.

Keep the code legible — it's there to be read, not to be compact. One statement per line; don't code-golf it.

## One at a time

If there are multiple things to explain, present exactly **one**, then stop and wait before moving to the next. Don't dump them all at once.

## The argument is the topic

Whatever text is passed with `/explain <topic>` is the specific thing to explain.

If no argument is passed, the topic is whatever is currently being discussed in the conversation at the moment the command was invoked — explain that.
