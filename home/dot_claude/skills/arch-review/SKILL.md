---
name: arch-review
description: Adversarial code review of a codebase on two axes — language-feature use (is the code idiomatic for its language, or translated-from-another-language?) and general architecture (module boundaries, abstractions, testability, error-handling design). Use when the user asks for an "architecture review", "language review", "code quality review", "tech review", "TS review / Go review / Rust review", "does X take advantage of TS/Go/Rust features", "could this have been done better", "is this idiomatic", "look at this codebase critically", "what would you change", "honest critique of <repo>". NOT for security review (use `/security-review`), perf benchmarking, or dependency audits.
---

# arch-review — adversarial two-axis code review

A principal-engineer second look at a codebase. **Default stance: skeptical.** The author is excited about the new shiny; your job is to ask "do we actually need this?" and "is there a simpler way?". The review has two distinct axes — assess both, separately, and surface findings ranked.

## Axes

### Axis 1: language-feature use

Is the code **idiomatic for its target language**, or does legacy structure from another language leak through? The trap to watch for: a port that compiles but reads as if it's still written in the source language with new keywords pasted on top.

**TypeScript specifically** — look for missed opportunities to use:

- **Discriminated unions + exhaustive switch** instead of stringly-typed kind fields with runtime branching. `switch (x.type)` with a `never`-typed default forces the compiler to catch new variants.
- **Branded types** (`type SessionId = string & { __brand: 'SessionId' }`) where a primitive carries semantic meaning that's currently relying on naming convention.
- **`satisfies` operator** instead of type assertions / casts when the goal is "verify this object matches the type without widening it." `as` is the wrong tool when `satisfies` would do.
- **Template literal types** for string formats that have structure (env var prefixes, path templates, kebab-case names, UUIDs).
- **Const assertions** (`as const`) on literal arrays/objects whose values are part of the public type surface.
- **`readonly` modifiers + `ReadonlyArray<T>`** on inputs that aren't mutated. Mutability defaults are backwards in JS — readonly should be the norm for function parameters.
- **Conditional / mapped types** when a generic boilerplate repeats across N near-identical interfaces.
- **`unknown` over `any`** at IO boundaries (JSON parse, env-var read, FFI return) — then narrow with type guards.
- **Exhaustive `switch` + `never`-typed default** for finite enum-like unions.
- **Structural typing leveraged consciously** — interfaces designed so test fakes and production impls satisfy the same shape without explicit `implements`.
- **`Map`/`Set` over `Record` and object-as-bag** when keys are dynamic or insertion order / cardinality matters.
- **Tagged template literals** for any string assembly that's currently `'foo' + bar + '='` chains.
- **`Object.freeze` / `as const`-frozen defaults** where a "default config" object is currently being shallow-spread defensively.
- **Top-level await + ES modules** — is the codebase still using async-IIFE wrappers or CommonJS-shaped patterns out of habit?

Other languages: apply the same lens. Go → channels vs callbacks, generics where prior interface-soup did the work, `errors.As` over type assertions. Rust → enums with data over tagged structs, `Result` over panic, ownership patterns. Python → dataclasses / `match`, `typing.Protocol`, async-native libraries.

**Symptoms to flag specifically:**
- "Stringly-typed dispatch": `if (op === 'restart')` chains where a union type + exhaustive switch would catch the next-added op at compile time.
- "Defensive boolean coercion": `if (x !== undefined && x !== '')` repeated 8 times where a brand or a non-empty-string type would localize the check.
- "Manual structural exhaustiveness": code that says "remember to add a new case here" in a comment instead of letting the compiler enforce it.
- "Translated-from-X smell": variable-naming, file-layout, error-handling patterns that match the source language too closely (e.g. `(value, error)` tuple-returns in TypeScript via `[T, Error | null]` instead of throw, snake_case-shaped types in TS, `interface FooImpl` with one impl in Java style).

### Axis 2: general architecture

Independent of language — could the **shape** of the thing have been better?

- Does every module / file boundary correspond to a real seam, or is it split because "files were getting long"?
- Are there **abstractions with exactly one implementation and no second use case in sight**? Dependency injection for testability is fine — but a `FooInterface` with `FooImpl` and `FooMock` and nothing else is often a unit-test artifact masquerading as a design.
- Is the dependency direction sane? Or does the orchestration layer reach down into utility modules while utilities import "just one thing" from upstream creating cycles?
- Does error handling **mean something**, or is it ceremonial? `catch (e) { /* ignore */ }` and `try { ... } catch { return null }` chains can be load-bearing or can hide real bugs — flag the ones where the difference matters.
- Is configuration shape coherent? One nested config object, or six top-level "options" args threaded through every function?
- Are the tests pinning **behavior** (input → output, with realistic fakes at the IO boundary) or just exercising **code paths** (mocking every dependency to the point that the test passes regardless of whether the production code does the right thing)?
- What would the on-call engineer need at 3am that isn't here? Logging, error context, "what state was the system in when this happened" affordances.
- Is anything **load-bearing only via documentation** — a comment that says "callers MUST do X" where the type system or function signature could enforce it?

## Output

Findings ranked **Blocker / High / Medium / Nit**. For each finding:

- **What** — one-line description of the problem.
- **Where** — file path + line number (absolute paths).
- **Why it matters** — what breaks, gets harder, or rots later if this stays.
- **Suggested change** — concrete: a code snippet, a refactor sketch, or a named alternative pattern. Not "consider using discriminated unions" — *show* the union.

End the review with one paragraph:

> **If I could only change one thing, it would be ___.**

Make that paragraph honest. It's the highest-leverage call you'd make if the author was only going to act on one finding. Not the easiest, not the safest — the one with the most ratio of "future pain avoided" to "work to do now."

## Scope discipline

This skill is **review only**. Do not:

- Run the test suite to "verify" findings — the review is a read of the source as it stands.
- Make code changes — surface the finding, don't implement the fix.
- Audit dependencies (license / CVE / version-staleness) — that's a different skill.
- Do a security review — likewise.
- Benchmark performance — likewise.
- Critique CHANGELOGs, CI configs, package.json metadata, or release tooling unless they directly cause one of the two axes above to suffer.

When in doubt about whether something is in scope, ask: "would this finding still matter if the project had perfect CI and zero dependencies?" If yes, it belongs. If no, omit it.

## Posture

The author asked for criticism. **Give criticism.** "Looks good" is not a useful review. If everything is genuinely fine on one axis, say so in one line and spend the review on the axis with real findings. Don't pad with nits to look thorough — three real Highs are worth more than ten Nits.

When you're certain about a finding, state it plainly. When you're uncertain (the code might have a reason you don't see), say "I might be missing context here, but ___" and ask the question. The author can confirm or correct.
