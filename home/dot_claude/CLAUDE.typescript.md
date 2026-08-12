# TypeScript style

## Array type syntax

Prefer the bracket form over the generic form:

- `readonly any[]` not `ReadonlyArray<any>`
- `T[]` not `Array<T>`

The bracket form is house style for both readonly and mutable arrays. Apply it consistently — new code, edits, and reviews.

## File naming — dominant-export files take the export's name

When a `.ts` file has one **dominant** exported declaration — a type (`class`, `interface`,
`enum`, or `type` alias) or a PascalCase-named const (a factory object, an augmentation-set
object) — name the file identically to that export: PascalCase, the exact same string. Minor
co-exports don't exempt it — dominance, not exactly-one-export, is the test. Files whose exports
are all lowercase-named (helper functions), multi-export files with no single dominant member,
and barrels (`index.ts`) keep descriptive kebab-case.

```ts
// NO
// application-lifetime.ts
export class ApplicationLifetime { … }

// YES
// ApplicationLifetime.ts
export class ApplicationLifetime { … }

// YES — dominant type export; a minor co-export doesn't change that
// BrowserLifetime.ts
export class BrowserLifetime { … }
export const BROWSER_LIFECYCLE_CATEGORY = "browser";

// unaffected — single export, but not a type: kebab-case stays
// resolve-condition-targets.ts
export function resolveConditionTargets(target: unknown) { … }

// unaffected — no single dominant member: kebab-case stays
// descriptor-verbs.ts
export function tryAdd(...) { … }
export function tryAddEnumerable(...) { … }
export function replace(...) { … }
```

The discriminator is **dominance**, not export count. `ServiceManifest.ts` exporting
`class ServiceManifest` plus a minor `interface ServiceManifestOptions` is the dominant case —
PascalCase, not kebab-case; treating a co-export as an automatic exemption was the old (wrong)
reading of this rule.

## Interface naming — `I`-prefix service interfaces, not DTOs

A **service** interface — one describing behavior, a contract with methods that something implements — gets an `I` prefix. A **DTO** interface — a plain data shape, a bag of fields with no behavior — does not.

```ts
// YES — service interface (behavior/contract): I-prefixed
interface IClock {
  now(): number;
}
interface IUserRepository {
  findById(id: string): Promise<User>;
}

// YES — DTO (plain data shape): no prefix
interface User {
  id: string;
  name: string;
  email: string;
}
```

The discriminator is behavior vs. data: if the interface is something you *implement* (methods, a capability), prefix it; if it's just the *shape* of a value passed around, leave it bare.

## No lambda types — always `Func`

**Never write a bare arrow/lambda function *type*.** Use `Func<Args, Return>` from
`@rhombus-toolkit/func` instead — every time, no exceptions.

```ts
// NO
type Factory = (...args: any[]) => unknown;
function signature(): (value: Ctor, ctx: ClassDecoratorContext) => void { … }
options: { readFile?: (path: string) => string | undefined }

// YES
type Factory = Func<any[], unknown>;
function signature(): Func<[Ctor, ClassDecoratorContext], void> { … }
options: { readFile?: Func<[string], string | undefined> }
```

`Func<in Args extends readonly any[] = any[], out Return = any> = (...args: Args) => Return`.
So a 0-arg `() => string` is `Func<[], string>`, a `(a: A) => B` is `Func<[A], B>`, a rest
`(...xs: any[]) => I` is `Func<any[], I>`. (Sibling specializations exist: `AsyncFunc`,
`Action` = `Func<Args, void>` — prefer `Func` unless told otherwise.)

**Scope of "type":** this is about function *types* — type-alias RHS, parameter/return/property
type annotations, type arguments. It does NOT touch arrow function *values/expressions*
(`(x) => x + 1`, `.map(p => …)`), interface/object *method signatures* (`foo(x): T`), or arrow
syntax inside doc comments / error-message strings. Add `import type { Func } from
"@rhombus-toolkit/func"` to any file that needs it.

## Control flow — always braces, always multiline

Every control-flow body (`if`, `else`, `else if`, `for`, `while`, `do`) is wrapped in `{ }` spanning multiple lines. Never a braceless body, never a one-line body crammed onto a single line.

```ts
// NO
if (!ready) return;
if (x) doThing();
for (const n of xs) total += n;

// YES
if (!ready) {
  return;
}
if (x) {
  doThing();
}
for (const n of xs) {
  total += n;
}
```

**Tooling note:** this is a lint rule, not a formatter transform — dprint/Prettier will keep an already-braced block multiline but won't insert braces. Enforce with ESLint `curly: ["error", "all"]` (plus a brace-position rule) or Biome `useBlockStatements`. When wiring up a project formatter, pair it with this lint rule.

## Private fields — always `#`- or `__`-prefixed

Every private field's name starts with `#` (hard private, the default) or `__` (soft private). Never an unmarked private field; never reach for the bare `private` modifier.

- `#field` — true runtime encapsulation, unreachable outside the class. Use by default.
- `__field` — private by convention, deliberately reachable: use it when a test (or similar) must read the internal, where `#` would make it genuinely unreachable.

```ts
// NO
class Cache {
  private store = new Map();
  private hits = 0;
}

// YES
class Cache {
  #store = new Map();
  __hits = 0; // a test reads this; `#` would hide it
}
```

## Exhaustiveness — `assertNever` at the end of switches

Close every exhaustive `switch` over a discriminated union with a `default` that calls `assertNever(x)`. Adding a new union member becomes a compile error instead of a silent fall-through. Apply the same pattern to exhaustive `if`/`else if` chains.

```ts
import { assertNever } from "@rhombus-toolkit/type-guards";

// assertNever(x: never): never — throws at runtime; the compile-time never check is the real value.

// NO
switch (shape.kind) {
  case "circle": return Math.PI * shape.r ** 2;
  case "rect": return shape.w * shape.h;
}

// YES
switch (shape.kind) {
  case "circle": {
    return Math.PI * shape.r ** 2;
  }
  case "rect": {
    return shape.w * shape.h;
  }
  default: {
    return assertNever(shape);
  }
}
```

## Boolean expressions — truthiness, coerce only when required

**Prefer truthiness over explicit comparison** wherever the falsy set is acceptable — including `.length`:

```ts
// NO
if (arr.length > 0) { ... }
if (str !== "") { ... }
if (obj !== null && obj !== undefined) { ... }

// YES
if (arr.length) { ... }
if (str) { ... }
if (obj) { ... }
```

Applies in all conditional positions: `if`/`while`/ternary test/`&&`/`||`.

**Coerce with `!!` only when an actual boolean value is required** — a boolean return type, a boolean field/prop, or JSX `{!!x && …}` to prevent a stray `0` or `""` from rendering. Don't scatter `!!` in plain conditionals; there, bare truthiness is the rule. Prefer `!!x` over `Boolean(x)`.

```ts
// NO — !! in a plain conditional
if (!!arr.length) { ... }

// YES — !! where a real boolean is needed
const hasItems: boolean = !!arr.length;
return !!result;
<Comp show={!!value} />
{!!count && <Badge n={count} />}
```

**Tooling note:** these play fine with typescript-eslint's `strict-boolean-expressions` at its defaults — `allowNumber`/`allowString` default to `true`, so non-nullable `number`/`string` truthiness (including `.length`) passes clean. The rule only flags truthiness on *nullable* values (`string | undefined`, etc.) and `any` — to keep truthiness there too, set `allowNullableBoolean` / `allowNullableString` / `allowNullableNumber: true`.

## Generators — yield sequences, buffer deliberately

Prefer a `function*` generator over accumulating into an array and returning it. Yielding is lazy — the consumer stops early at no cost, recursive cases compose via `yield*` with no intermediate allocations, and the caller materializes only when a concrete array is actually required.

```ts
// NO
function resolveConditionTargets(target: unknown): string[] {
  if (typeof target === "string") {
    return [target];
  }
  if (typeof target === "object" && target !== null) {
    const obj = target as Record<string, unknown>;
    const out: string[] = [];
    for (const key of ["types", "import", "module", "default", "require", "node", "bun"]) {
      const v = obj[key];
      if (typeof v === "string") {
        out.push(v);
      } else if (typeof v === "object" && v !== null) {
        out.push(...resolveConditionTargets(v));
      }
    }
    return out;
  }
  return [];
}

// YES
function* resolveConditionTargets(target: unknown): Generator<string> {
  if (typeof target === "string") {
    yield target;
    return;
  }
  if (typeof target === "object" && target !== null) {
    const obj = target as Record<string, unknown>;
    for (const key of ["types", "import", "module", "default", "require", "node", "bun"]) {
      const v = obj[key];
      if (typeof v === "string") {
        yield v;
      } else if (typeof v === "object" && v !== null) {
        yield* resolveConditionTargets(v);
      }
    }
  }
}
```

Two payoffs this example makes concrete: (1) the recursive `out.push(...resolveConditionTargets(v))` — which builds a fresh array at every recursion level and then spreads it into `out` — collapses to `yield* resolveConditionTargets(v)`, threading values through directly; (2) a caller that needs an array writes `[...resolveConditionTargets(x)]` at the point of use, not inside the function.

**Buffer deliberately when buffering is clearly the better choice:**

- The caller needs `.length`, random indexing, or multiple passes over the result.
- All elements are needed together anyway — sorting, dedup, grouping, reversing.
- A small fixed literal where an array reads clearer than a generator.
- A public API boundary typed as `T[]` where consumers expect a materialized array.
- Laziness would hold a resource open (file handle, DB cursor, lock) longer than intended.

Return type: annotate as `Generator<T>` or `IterableIterator<T>`. Both are correct; `Generator<T>` is more precise and preferred when the function explicitly returns nothing.

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

## Overrides — always write `override`

Every member that redeclares a base-class member carries the `override` keyword, **implementations of `abstract` members included**. It puts the relationship at the member itself, and it turns a renamed or deleted base member into a compile error instead of a silently-orphaned method.

```ts
abstract class Visitor<R> {
  protected abstract visitUnion(node: UnionNode): R;
}

// NO
class Printer extends Visitor<string> {
  protected visitUnion(node: UnionNode) { … }
}

// YES
class Printer extends Visitor<string> {
  protected override visitUnion(node: UnionNode) { … }
}
```

**`noImplicitOverride` does not cover the abstract case** — it only fires when a *concrete* base member is redeclared, so a class implementing an abstract base compiles clean either way. That exemption is exactly why this is a convention rather than something the compiler will remember for you. Turn the flag on regardless; it covers the other half.

## Blank lines — one between every member, one after a region opener

Separate sibling declarations with exactly one blank line — between a declaration's closing `}`
(or end) and the next member's doc comment or declaration. Applies at module, namespace, and
class level alike: functions, methods, interfaces, classes. A `// #region` opener also gets a
blank line before the first doc comment or member that follows it. A run of tightly-coupled
one-line aliases may sit adjacent when splitting them would obscure the pairing.

```ts
// NO — members packed together, region opener crowded
// #region factories
/** A constructor signature. */
export function ctor(instanceType: Type): CtorType { … }
/** Reads a token back into the Type it spells. */
export function from(token: string): Type { … }

// YES — a blank after the opener and between every member
// #region factories

/** A constructor signature. */
export function ctor(instanceType: Type): CtorType { … }

/** Reads a token back into the Type it spells. */
export function from(token: string): Type { … }
```

**Tooling note:** this is authored, not formatter-enforced — dprint's TypeScript plugin has no
blank-line *insertion* rule (only enum `memberSpacing`, maintain-only), and Prettier likewise
only preserves. Both maintain authored blanks, so write them once and the formatter keeps them.
Where ESLint runs, `@stylistic/padding-line-between-statements` can enforce the member case.

## Single-consumer state — close over it, don't sibling it

When module/namespace state is read by exactly one function, the function owns it: wrap the pair
in an IIFE that declares the state and returns the function. A sibling `const` leaks the state to
every other member of the scope and can orphan when its function moves.

```ts
// NO — the memo is visible to every sibling in the scope
export function from(token: string): Type { /* … reads parsed … */ }
const parsed = new Map<string, Type>();

// YES — the memo lives inside the only function that reads it
export const from = (() => {
  /** Every token already read, so a repeated request skips the lexer. */
  const parsed = new Map<string, Type>();
  return function from(token: string): Type {
    /* … */
  };
})();
```

Keep the inner function **named** — stack traces and profiles still say `from`. The doc comment
rides the exported const, so hover/intellisense is unchanged. State genuinely shared by several
members stays a scope-level declaration, placed beside its users.
