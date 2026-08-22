# Code style — all languages

Principles that apply to every language. Language-specific style lives in its own sibling
(`CLAUDE.codestyle.ts.md`; per-language leaves are minted lazily); where a specific file elaborates one of these, the
specific file wins on mechanics.

## The budget is reader frames, not characters

Reading code is a depth-first traversal on a lossy stack: a reader forced to descend into a
callee to learn what it does cannot cheaply restore the frame they left — the place they meant to
return to is simply gone. Every style trade is priced in these frames, not in characters or
repetitions. Terseness rules delete what is derivable *without leaving the frame* (restated
signatures, self-evident comments); naming rules spend characters exactly where the alternative
is leaving it. Same axis as DRY-as-a-trade: minimize total understanding cost.

## The name is the zeroth doc comment

The escalation ladder is name → doc sentence → source, each level existing to spare the reader
the next. A name that fails forces a descent no doc can refund, because by the time the doc
helps, the frame is already lost.

- A member's name states WHAT it does — verb and object together (`buildCallSite`,
  `detectFailure`), never a bare noun or elliptical verb.
- Rarely, if ever, HOW. What-names survive refactors; how-names rot into lies the day the
  implementation changes.
- The unit that must read as a sentence is the *call-site expression*, not the identifier: the
  receiver may supply the noun and the method the verb (`cycleGuard.visiting(x)`), so a field
  holding a device is named for the mechanism it is.
- The boundary of "rarely how": name the how when the how IS the contract a caller's correctness
  depends on (`reverse` vs `toReversed`, `getOrInsertComputed`). A mechanism extracted into a
  named device is a how one level up but a what at its own level — which is exactly how
  mentioning it becomes legal.

Every method name pairs an explicit verb with its object. A bare noun or an elliptical verb names nothing:

```ts
// NO — bare noun / elliptical verb; the call site names nothing
class Resolver {
  #planFor(node: Node): Plan { … }
  #failure(node: Node): boolean { … }

  resolve(node: Node): Plan {
    if (this.#failure(node)) {
      throw new Error("cycle");
    }
    return this.#planFor(node);
  }
}

// YES — verb + object; the call site reads as a sentence
class Resolver {
  #getPlanFor(node: Node): Plan { … }
  #detectFailure(node: Node): boolean { … }

  resolve(node: Node): Plan {
    if (this.#detectFailure(node)) {
      throw new Error("cycle");
    }
    return this.#getPlanFor(node);
  }
}
```

The same rule covers a field that holds a device, not just a method that performs an action — name the field for the mechanism it is, not a generic one-word label:

```ts
// NO — the field name gives no context clues; the reader must go look
if (this.#visiting(x)) { … }

// YES — the field names the mechanism; the reader can correctly guess the
// whole thing (a cycle-detection guard) without leaving this function
if (this.#cycleGuard.visiting(x)) { … }
```

## Local variables — inline the trivial, name what earns it

A single-use local should be inlined unless its initializer earns the name. "Earns it" is about the initializer's **complexity**, not how many times the value is used — a single-use binding is justified when the expression is busy enough that a name aids readability, and pointless when the expression is trivial.

Inline when the initializer is a bare call, property access, or short literal that reads fine at the use site. Keep the name when it's a ternary, a multi-step transform, a long/nested expression, or a multi-statement closure — something that would clutter the surrounding statement if inlined, or whose name documents an otherwise-opaque value.

```ts
// NO — single-use binding of a trivial call; inline it at the use site
const targets = resolveConditionTargets(target);
for (const t of targets) { … }
// → for (const t of resolveConditionTargets(target)) { … }

// YES — also single-use, but the initializer is busy enough that the name earns its place
const subpath = subKey === "." ? "" : subKey.replace(/^\.\/?/, "");
out.push({ subpath, targetRel: t.replace(/^\.\/?/, "") });
```

The discriminator is the initializer, not the use-count: both bindings above are used once; only the trivial one should be inlined.

*First-cut heuristic — the exact "too simple to name" threshold is still being calibrated; expect refinement.*

## Doc comments — one sentence is the norm, not a floor

A single sentence covers nearly every doc comment: a noun phrase naming the thing, often with a
short gloss. Never restate what the name, type, parameter order, or overloads already say — the
signature is part of the documentation. A fact lives at one declaration only: something already
documented at its owning declaration is never restated where that declaration is used — link to it
or say nothing. Proximity counts too — a neighbor's doc counts as already-read. Every sentence has
to pass "what does the reader DO with this?" — vague meta-description that informs no call gets
deleted, not reworded. Prefer concrete wording over clever abstraction; if a reviewer would call it
word soup, rewrite with concrete cases or delete it.

```ts
// NO — restates the param, narrates the object form, says nothing the signature doesn't
/**
 * Creates a Type node.
 * @param name - the type's name
 * @remarks Accepts a string for the shorthand form, or an object for the full form —
 * the object form takes the node's fields directly.
 */
function typefor(name: string | { name: string; strict?: boolean }): Type { … }

// YES — one sentence; the signature carries the rest
/** Names a type by its declared identifier. */
function typefor(name: string | { name: string; strict?: boolean }): Type { … }
```

Extra lines beyond the sentence are earned only by an `@example`, an `@throws`, or one fact not
derivable from the signature, the code below, or a neighbor's doc — not by hedging or restating.

A full paragraph is justified case-by-case, when the member is the single designated home of
several independent, interacting, caller-tripping facts — a factory that canonicalizes its inputs
in three observable ways, a matcher whose semantics are four negatives a reader will otherwise
assume. Don't blanket-compress those down to a sentence; the paragraph is what's earned there.

Reference-sized content — a grammar, a wire format — outgrows doc comments entirely: extract it to
a spec doc and leave a one-line pointer.

A comment already sitting in the codebase is not precedent for this style — it may simply not have
been reviewed yet.

## Accept permissive, return expressive

Postel's law, typed: parameters take the **widest honest type** the body actually needs; returns declare the **narrowest concrete truth** about the value actually produced.

```ts
// NO — demands a concrete array; return type hides the Set actually built
function getIds(items: string[]): Iterable<string> {
  return new Set(items);
}

// YES — accepts anything iterable; return type keeps the Set's own capabilities
function getIds(items: Iterable<Item>): ReadonlySet<string> {
  return new Set(Iterator.from(items).map(item => item.id));
}
```

On the input side: prefer `Iterable<T>` over `T[]` or a concrete container class, a structural shape over a class — never demand more capability than the body uses. On the output side: never launder a capable value through a weaker return type — `ReadonlySet<T>` not `Iterable<T>` when a `Set` is returned, `IteratorObject<T>` not a hand-waved `Iterable<T>` for an iterator-helper chain, `Generator<T>` only when the function itself is a generator. A caller loses `.has`/`.size`/helper methods the value genuinely carries the moment the signature under-declares it.

## Single-use helpers — earn extraction with reuse or a compressing name

Extracting a function or method used at exactly one call site is the exception, not a default move. Inline the logic at its one call site — even a fat multi-statement arrow inside an iterator chain — unless the extraction is earned: by actual reuse elsewhere, or, rarely, by a name that genuinely compresses understanding of an otherwise-opaque block. "The chain looks cleaner with it pulled out" is not one of those reasons.

```ts
// NO — a private method that exists only to tidy one .map(...)
class Report {
  #summarize(row: Row): Summary {
    return { id: row.id, total: row.items.reduce((n, i) => n + i.qty, 0) };
  }

  build(rows: Row[]): Summary[] {
    return rows.map(row => this.#summarize(row));
  }
}

// YES — read exactly once, right here; the arrow stays inline
class Report {
  build(rows: Row[]): Summary[] {
    return rows.map(row => ({
      id: row.id,
      total: row.items.reduce((n, i) => n + i.qty, 0),
    }));
  }
}
```

## Ternaries stay single-line; multiline literals chop fully

Two related rules.

**A conditional expression that would span multiple lines is not written as a ternary.** Restructure as a guard `if`/`return`, or name the operands so the ternary fits on one line. A ternary that's outgrown one line is a sign the branches deserve statements, not an excuse to hard-wrap the `?`/`:`.

```ts
// NO — multiline ternary, true-arm is a cramped two-prop object
function toResult(isValid: boolean, input: Input): Result {
  return isValid
    ? { status: "ok", value: computeValue(input), timestamp: Date.now() }
    : { status: "error", value: undefined };
}

// YES — guard-return, each literal fully chopped
function toResult(isValid: boolean, input: Input): Result {
  if (!isValid) {
    return {
      status: "error",
      value: undefined,
    };
  }
  return {
    status: "ok",
    value: computeValue(input),
    timestamp: Date.now(),
  };
}
```

**An object literal that goes multiline is fully chopped** — exactly one property per line, never two crammed onto one to save a line.

```ts
// NO — two props sharing a line
const opts = {
  scope: "singleton", tags: ["a", "b"],
  lazy: true,
};

// YES
const opts = {
  scope: "singleton",
  tags: ["a", "b"],
  lazy: true,
};
```

Single-line ternaries and single-line literals are both still fine — these rules only fire once the construct has already decided to span multiple lines.

Only the shortest object literals stay inline. A literal that contains a call expression, or holds more than a couple of tiny members, goes fully chopped — one property per line — even when it's the sole expression body of an arrow.

## DRY is a trade, not a rule

Repetition is not itself a defect. Weigh a shared abstraction against what it removes on **total understanding cost**, not on how many times something repeats: a shared name and an indirection at every call site are a cost the abstraction has to repay, not a free win. When the reference costs about as many characters — and as much "what is this again?" — as the duplication it replaces, it's a loser: a vocabulary item invented for a problem that didn't exist.

```ts
// NO — a base pulled out for two implementors, each already trivial
interface ElementBase {
  element: Widget;
}
interface Anchor extends ElementBase {
  href: string;
}
interface Trigger extends ElementBase {
  onFire: Func<[], void>;
}

// YES — the member written directly in both; two spellings beat a third concept
interface Anchor {
  element: Widget;
  href: string;
}
interface Trigger {
  element: Widget;
  onFire: Func<[], void>;
}
```

`ElementBase` here saves one line of duplication and costs a name every future reader of either interface has to look up to know what `element` even is. Two plain spellings are cheaper to read than one base plus two extensions.

Judge case by case — a genuinely shared, non-trivial shape (several fields, an invariant that must stay in lockstep, three-plus implementors) earns the abstraction easily; a one- or two-field shape used twice usually doesn't. When in doubt, prefer inlining a base back into its implementors over inventing one preemptively: collapsing two inlined copies into a shared type later is a mechanical merge, while un-inlining a bad abstraction means first proving every use site actually agrees.
