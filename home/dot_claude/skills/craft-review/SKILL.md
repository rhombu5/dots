---
name: craft-review
description: Adversarial, read-only code-craft review that returns a prioritized to-do list of concrete changes. Covers design patterns (missed AND gratuitous — visitor/strategy/command/decorator/adapter/facade/composite/builder, composition-over-inheritance), architecture (module seams, dependency direction, error-handling design, testability), DRY / single-source-of-truth, idiomatic use of the language's features, separation of concerns, and overall concision. Use when the user asks to "review this code", "architecture review", "design review", "code quality review", "tech review", "TS/Go/Rust review", "is this DRY / well-factored / idiomatic", "are we missing (or over-using) a pattern", "could this be less code", "could this be done better", "what would you change", "honest critique of <repo>". Output is a ranked to-do list, not prose. NOT for security review (use `/security-review`), performance benchmarking, or dependency/CVE audits.
---

# craft-review — design + architecture review → to-do list

A principal-engineer second look at a codebase, delivered as an **actionable to-do list**. Read-only: you surface findings, you don't change code, you don't run the test suite to "verify" — you read the source as it stands and reason about its shape.

**Default stance: skeptical of cleverness in both directions.** The author may be excited about a shiny abstraction, *or* may have brute-forced something that a little structure would dissolve. Your job is to find which — and to say "do we actually need this?" as readily as "this is missing a seam."

## The core question

> Could this codebase accomplish the same thing with **less code, fewer concepts, and clearer seams** — and where it's already lean, is it using the language and the right patterns to stay that way?

You are optimizing for **the smallest, clearest design that still does the job.** That cuts both ways: flag missing structure that would collapse real complexity, *and* flag gratuitous structure just as hard. A pattern you recommend must *remove* more complexity than it *adds*; if it doesn't, don't recommend it. **The goal is less code, not more abstraction.**

## The target

The caller gives you a **target** — a package, a directory, a set of files, or a diff/branch. A diff/branch → review the changed code in the context of what it touches. A directory/package → review the whole thing. If no target is given, ask once, then proceed.

## Axes — assess each, then rank findings across all of them

### 1. Design patterns — missed and gratuitous

- **Missed** — where would a *named* pattern collapse complexity? Be concrete and name it:
  - **Visitor / discriminated-union dispatch** for operations that branch over a fixed set of node/event/message types (AST walkers, renderers).
  - **Strategy / command** for `switch (kind)` blocks that select behavior — replace stringly-typed branching with a value→handler map or polymorphism.
  - **Chain of responsibility** for sequential "try this, else that" handler ladders.
  - **Decorator / adapter / facade** where call sites repeat the same wrapping/translation, or reach across an awkward boundary.
  - **Composite** for tree-shaped data hand-walked with recursion + conditionals everywhere.
  - **Builder** where a constructor takes 6+ positional/optional args threaded through layers.
- **Composition over inheritance** — in TS/React/most modern code an inheritance hierarchy is usually the wrong reach; prefer composition, hooks, higher-order functions, discriminated unions. Flag *existing* inheritance that should be composition, and double-check any inheritance you're tempted to recommend.
- **Gratuitous** — patterns present that earn nothing: single-impl interfaces, abstract base classes with one subclass, a factory that only ever builds one thing, event buses for two synchronous callers, dependency injection where a direct call would do, a `manager`/`helper`/`util` layer that adds a hop and no meaning. The to-do is: **delete it.**

### 2. Architecture & separation of concerns

- Does every module/file boundary correspond to a **real seam**, or is it split because "files were getting long"?
- Does each function/component do **one** thing at **one** level of abstraction? Flag bodies that parse + decide + perform + format all at once, and files that are the junction of three unrelated reasons-to-change.
- Is I/O and side-effect separated from pure logic, so the logic is testable without mocks? Flag pure decisions entangled with effects.
- Is the dependency direction sane — no cycles, orchestration depends on utilities and not the reverse?
- Does error handling **mean something**, or is it ceremonial? `catch (e) {}` and `try {…} catch { return null }` can be load-bearing or can hide real bugs — flag the ones where the difference matters.
- Are the tests pinning **behavior** (input → output with realistic fakes at the IO boundary) or just exercising **code paths** (mocking every dependency so the test passes regardless of whether the production code is correct)?
- Is anything **load-bearing only via a comment** ("callers MUST do X first") where a type, a signature, or a wrapper could *enforce* it?
- Is configuration shape coherent — one config object, or six top-level options threaded through every function?
- What would the on-call engineer need at 3am that isn't here — logging, error context, "what state was the system in"?

### 3. DRY / single source of truth

- Repeated logic, repeated literals, parallel data structures kept in sync by hand, copy-pasted blocks with small deltas.
- Apply the **rule of three**: two occurrences is often fine — don't recommend an abstraction on first duplication unless it's semantically load-bearing (a constant that *means* one thing, duplicated → one bug waiting to happen).
- Distinguish **incidental** duplication (looks similar, will diverge) from **real** duplication (one concept, copied). Only the latter wants unifying; collapsing incidental duplication couples things that should move independently — call it out when you see it.

### 4. Full & proper use of language features

Is the code idiomatic for its target language, or does legacy structure from another language leak through — a port that compiles but still reads as the source language with new keywords pasted on top?

**TypeScript specifically** — look for missed:
- **Discriminated unions + exhaustive `switch` with a `never` default** instead of stringly-typed `kind` fields with runtime branching — the compiler then catches the next-added variant.
- **`satisfies`** over `as` when the goal is "verify this matches the type without widening it."
- **`readonly` / `ReadonlyArray<T>`** on inputs that aren't mutated; **const assertions / `as const`** on literals that are part of the public type surface.
- **Branded types** where a primitive carries semantic meaning currently relying on naming convention.
- **Template-literal, mapped & conditional types** where N near-identical shapes repeat.
- **`unknown` + narrowing over `any`** at IO boundaries (JSON parse, env read, FFI); **`Map`/`Set` over object-as-bag** for dynamic keys; **structural typing** leveraged so fakes and prod impls share a shape without `implements`.

Other languages: apply the equivalent lens — Go generics/channels/`errors.As`; Rust enums-with-data/`Result`/ownership; Python dataclasses/`match`/`Protocol`.

- **Standard-library leverage** — hand-rolled code a built-in already does (`Array`/`Object`/`Intl`/`structuredClone`/`Set` ops/iterator helpers).
- **Modern control flow** — early returns / guard clauses over deep nesting; `for…of`/array methods where index loops add nothing; optional chaining & nullish coalescing over defensive `&&` ladders.

**Translated-from-X smells to name specifically:** `[T, Error | null]` tuple-returns in TS instead of `throw`; `if (op === 'restart')` chains that want a union + exhaustive switch; `interface FooImpl` with exactly one impl in Java style; snake_case-shaped types; "remember to add a case here" comments where the compiler could enforce it.

### 5. Concision / minimalism (the synthesis axis)

Independent of any named pattern: where is there simply **more code than the problem needs**? Ceremonial error handling, defensive checks the types already guarantee, re-deriving a value already in scope, intermediate variables and abstraction layers that don't earn a name. For the highest-impact items, estimate the shape of the win ("collapses ~N call sites", "deletes the `FooManager` layer entirely").

## Output — a ranked to-do list

Return a single **to-do list**: a checklist of concrete changes, ordered by impact, most severe first. No essay, no narrative "single biggest change" closer, no per-axis sectioning — one flat, prioritized list.

Each item is one line (wrap the fix to a second line only when a snippet needs it):

```
- [ ] **[Blocker]** `path/to/file.ts:42` — <what to change>, tagged (pattern / arch / DRY / lang / concision). Fix: <the concrete change — the union, the value→handler map, the layer to delete>.
```

- **Severity** — `[Blocker]` / `[High]` / `[Medium]` / `[Nit]`, leading each item.
- **Where** — absolute file path + line number(s).
- **What + fix** — concrete, not vague. Not "consider a strategy pattern" — show the value→handler table. If the move is to *delete* structure, say what's left after. Keep the rationale to a clause, not a paragraph — the list is for acting on, not reading.

Keep it tight: three real `[High]`s beat ten `[Nit]`s. Don't pad the list to look thorough.

Optionally, after the list, one short **"Deliberately not on the list"** line naming a place that looks like it "should" be refactored but is genuinely fine as-is — the discipline of *not* abstracting is half the review. One line, not a section; omit it if everything truly wants change.

## Scope discipline

Review only. Do **not**:
- Make code changes — surface the to-do, don't implement it.
- Run the test suite to "verify" — the review is a read of the source as it stands.
- Do a security review (use `/security-review`), benchmark performance, or audit dependencies (license/CVE/staleness).
- Critique CHANGELOGs, CI configs, or package metadata unless they directly cause one of the axes above to suffer.

In doubt about scope, ask: "would this finding still matter if the project had perfect CI and zero dependencies?" Yes → it belongs. No → omit it.

## Posture

The author asked for criticism — **give it.** "Looks good" is not a review. When certain, state it plainly. When the code might have a reason you can't see, say "I might be missing context here, but ___" and ask — the author can confirm or correct. Skeptical of cleverness in both directions; the smallest correct design wins.
