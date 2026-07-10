# TypeScript style

## Array type syntax

Prefer the bracket form over the generic form:

- `readonly any[]` not `ReadonlyArray<any>`
- `T[]` not `Array<T>`

The bracket form is house style for both readonly and mutable arrays. Apply it consistently — new code, edits, and reviews.

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
