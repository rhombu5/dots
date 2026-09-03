# TypeScript style

## Array type syntax

Prefer the bracket form over the generic form:

- `readonly any[]` not `ReadonlyArray<any>`
- `T[]` not `Array<T>`

The bracket form is house style for both readonly and mutable arrays. Apply it consistently — new code, edits, and reviews.

**Project config wins when it disagrees.** This is a default for projects with no configured opinion. Where a project's own style tooling (e.g. dprint, an ESLint `array-type` rule) takes a stance on array-type syntax, follow that config instead.

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

**Exception — an interface and its sole implementer may share a file, named after the interface.** When exactly one class implements a given interface, the two may live together; the file takes the *interface's* name even though the class is where the logic sits.

```ts
// YES — IClock.ts
export interface IClock {
  now(): number;
}
export class SystemClock implements IClock {
  now(): number { … }
}
```

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

## No lambda types — always `Func`, `Ctor`, `AbstractCtor`

**Never write a bare arrow/lambda function type, constructor type, or abstract-constructor
type.** Use `Func<Args, Return, This?>`, `Ctor<Args, Instance>`, and
`AbstractCtor<Args, Instance>` instead — every time, no exceptions.

```ts
// NO
type Factory = (...args: any[]) => unknown;
function signature(): (value: Ctor, ctx: ClassDecoratorContext) => void { … }
options: { readFile?: (path: string) => string | undefined }
type Build = new (...args: any[]) => Widget;
type BuildAbstract = abstract new (...args: any[]) => Widget;

// YES
type Factory = Func<any[], unknown>;
function signature(): Func<[Ctor, ClassDecoratorContext], void> { … }
options: { readFile?: Func<[string], string | undefined> }
type Build = Ctor<any[], Widget>;
type BuildAbstract = AbstractCtor<any[], Widget>;
```

```ts
type Func<in Args extends readonly any[] = any[], out Return = any, in This = void> =
  (this: This, ...args: Args) => Return;
type Ctor<in Args extends readonly any[] = any[], out Instance = any> =
  new (...args: Args) => Instance;
type AbstractCtor<in Args extends readonly any[] = any[], out Instance = any> =
  abstract new (...args: Args) => Instance;
```

So a 0-arg `() => string` is `Func<[], string>`, a `(a: A) => B` is `Func<[A], B>`, a rest
`(...xs: any[]) => I` is `Func<any[], I>`. The 3rd parameter is only needed when the function
must run bound to a specific `this` — the default, `void`, means "unbound, don't rely on
`this`." A concrete constructor type is `Ctor<[A, B], Instance>`; an abstract one (mixins, a
class decorator applied to an `abstract class`) is `AbstractCtor<[A, B], Instance>`.

**`Func`, `Ctor`, and `AbstractCtor` usage is required.** Two more specializations exist for
convenience, not required: `AsyncFunc<Args, Return, This?>` (`Func` returning a `Promise`) and
`Action<Args, This?>` / `AsyncAction<Args, This?>` (`Func`/`AsyncFunc` returning `void`). Reach
for them when they read better; a bare `Func<Args, Promise<Return>>` or `Func<Args, void>` is
equally correct.

**Scope of "type":** this is about function/constructor *types* — type-alias RHS,
parameter/return/property type annotations, type arguments. It does NOT touch arrow function
*values/expressions* (`(x) => x + 1`, `.map(p => …)`), interface/object *method signatures*
(`foo(x): T`), or arrow syntax inside doc comments / error-message strings.

**Import from `@rhombus-toolkit/types`** — `Func`/`Ctor`/`AbstractCtor` and siblings live there
(a type-only package, no runtime). Not from `@rhombus-toolkit/func`, and never re-declared
locally.

## `@rhombus-toolkit/*` — reach for it before writing a local utility

Make good use of the `@rhombus-toolkit/*` packages. The two that come up in every project:

- **`@rhombus-toolkit/types`** — `Func`, `Ctor`, `AbstractCtor` and their `AsyncFunc` /
  `Action` / `AsyncAction` siblings, per "No lambda types" above.
- **`@rhombus-toolkit/type-guards`** — `assertNever` for exhaustiveness (see "Exhaustiveness"
  below), and the `is*` guards: `isDefined`, `isObject`, `isFunction`, `isIterable`, `isPromise`, …

**The `is*` guards are for passing directly, in place of a lambda** — `.filter(isDefined)`,
`.find(isFunction)`, `.every(isIterable)`. That is the only place to use them. Inside an ordinary
conditional, write the check inline; a guard call there is a hop the reader has to resolve for
nothing.

```ts
import { isDefined } from "@rhombus-toolkit/type-guards";

// NO — lambda where a guard reference fits
items.filter(x => x !== undefined);
items.filter(x => isDefined(x));

// NO — guard call inside an ordinary conditional
if (isDefined(value)) { … }

// YES
items.filter(isDefined);
if (value !== undefined) { … }
```

`.filter(isDefined)` drops only `undefined` and keeps `0`/`""`; when every falsy value should go,
`.filter(Boolean)` (see "Boolean expressions" below) is the right spelling.

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

## Private fields — always `#`- or `_`-prefixed

Every private field's name starts with `#` (hard private, the default) or `_` (soft private). Never an unmarked private field; never reach for the bare `private` modifier.

- `#field` — true runtime encapsulation, unreachable outside the class. Use by default.
- `_field` — private by convention, deliberately reachable: use it when a test (or similar) must read the internal, where `#` would make it genuinely unreachable.

```ts
// NO
class Cache {
  private store = new Map();
  private hits = 0;
}

// YES
class Cache {
  #store = new Map();
  _hits = 0; // a test reads this; `#` would hide it
}
```

## Exhaustiveness — `assertNever` at the end of switches and if/elseif chains

Close every exhaustive `switch` over a discriminated union with a `default` that calls
`assertNever(x)`. Adding a new union member becomes a compile error instead of a silent
fall-through. Apply the same pattern to exhaustive `if`/`else if` chains — `assertNever` in the
final `else`.

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

```ts
// NO
if (shape.kind === "circle") {
  return Math.PI * shape.r ** 2;
} else if (shape.kind === "rect") {
  return shape.w * shape.h;
}

// YES
if (shape.kind === "circle") {
  return Math.PI * shape.r ** 2;
} else if (shape.kind === "rect") {
  return shape.w * shape.h;
} else {
  return assertNever(shape);
}
```

## Boolean expressions — truthiness, coerce only when required

**Use truthiness whenever it achieves the same result as being explicit** — including `.length`:

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

**`.filter(Boolean)` / `.find(Boolean)` are the point-free spelling of a truthiness check inside a chain** — use them over `.filter(x => !!x)` or `.filter(x => x)` when narrowing falsy values out of an iterable.

```ts
// NO
items.filter(x => !!x);
items.filter(x => Boolean(x));

// YES
items.filter(Boolean);
```

**Tooling note:** TypeScript 5.5+ infers `.filter(Boolean)` as a type predicate, narrowing
`(T | null | undefined)[]` down to `T[]` with no manual type guard needed.

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

Keep the inner function **named** — stack traces and profiles still say `from`. When the
function carries **overloads**, write it as a full `function` declaration inside the IIFE —
overload signatures, then the implementation — and `return from;` on its own line: the const's
type is inferred from the declaration, so the overload faces survive without re-spelling them in
an annotation, which a returned function *expression* would force. The doc comment
rides the exported const, so hover/intellisense is unchanged. **The wrapper is an arrow,
deliberately**: an arrow IIFE introduces no `this`/`arguments` boundary, so the wrapper is
transparent to context — nothing inside can capture or shadow a `this` the enclosing scope didn't
already have (a `function` wrapper would mint its own). The arrow wraps; the returned function is
the one that owns a `this` if the member needs one. State genuinely shared by several members
stays a scope-level declaration, placed beside its users.

## Variance — annotate `in`/`out` where the role is definite

Every type parameter on a generic interface / type alias whose variance role is definite gets the
explicit modifier: `in` where the type is consumed (parameter positions), `out` where it is
produced (return/read positions), `in out` when it genuinely flows both ways. Leave a parameter
bare only when its variance is truly mixed or undecided.

```ts
// NO — variance left for the reader (and the checker) to re-derive
interface Func<Args extends readonly any[], Return> {
  (...args: Args): Return;
}

// YES — the flow direction is declared (simplified: omits the optional `This`
// parameter documented in "No lambda types" above)
interface Func<in Args extends readonly any[] = any[], out Return = any> {
  (...args: Args): Return;
}
interface Ctor<in Args extends readonly any[] = any[], out Instance = any> {
  new(...args: Args): Instance;
}
```

Three payoffs: the declaration *documents* which way values flow; TS **enforces** an annotated
variance (a member that violates it errors at the declaration, not at some distant use); and the
checker skips structural variance measurement for annotated params. This is declaration-site
style — call sites are unaffected.

## Iterator chains over loops

**Default to an iterator-helper chain; a hand-rolled `for` loop is the exception, not a
stylistic alternative.** Before writing a `for`, check whether the body is really
filter/map/find/reduce wearing a loop's clothes — an accumulator that only ever pushes, an early
`return` that's actually a search, a running total — and reach for
`Iterator.from(x).map(...).filter(...).find(...)`, `.toArray()`, a `new Set(...)`/`new Map(...)`
wrapping one, or `.reduce(...)` instead. Laziness survives the rewrite: `.find` still
short-circuits, `.map` over a generator stays unevaluated until something consumes it. Keep the
loop only when it earns its place: interleaved mutation, accumulation across multiple
collections at once, or a body that genuinely doesn't reduce to map/filter/find/reduce shape.

```ts
// NO
function activeIds(items: Item[]): Set<string> {
  const out = new Set<string>();
  for (const item of items) {
    if (item.active) {
      out.add(item.id);
    }
  }
  return out;
}

// YES
function activeIds(items: Iterable<Item>): ReadonlySet<string> {
  return new Set(
    Iterator.from(items)
      .filter(item => item.active)
      .map(item => item.id),
  );
}
```

```ts
// NO — accumulator loop hiding a find and a reduce
function firstAdmin(users: User[]): User | undefined {
  for (const u of users) {
    if (u.role === "admin") {
      return u;
    }
  }
  return undefined;
}
function totalQty(items: Item[]): number {
  let sum = 0;
  for (const item of items) {
    sum += item.qty;
  }
  return sum;
}

// YES
function firstAdmin(users: Iterable<User>): User | undefined {
  return Iterator.from(users).find(u => u.role === "admin");
}
function totalQty(items: Iterable<Item>): number {
  return Iterator.from(items).reduce((sum, item) => sum + item.qty, 0);
}
```

A fat per-element body stays inline as a multi-statement arrow, even where it clutters the chain — single-use helpers are rarely justified (see Single-use helpers above). Reach for a named function only when the logic is reused elsewhere, or its name genuinely compresses understanding of an otherwise-opaque block — never merely to keep the chain visually thin.

This composes with the Generators section above: a generator is still the right *producer* for yield-shaped output. This rule governs the *consumer* side — once something is iterable, prefer transforming and consuming it through a chain rather than a loop.

Pass a function reference point-free — `.every(Type.isOptional)`, `.map(Type.from)` — instead of wrapping it in a lambda, whenever the callback's arity and `this`-freedom allow it. Wrap only when something forces it: overload resolution that needs the call-site's own argument type to pick a signature (`Object.freeze`'s overloads are the canonical forced-wrap — a bare reference collapses to the wrong one), or a function that depends on a `this` the chain doesn't supply.

## Namespace members — always reference qualified

Reference a namespace's exported members through the namespace qualifier even from inside the namespace itself: `Type.adopt(...)`, `CallSite.constant(...)` — never the bare `adopt(...)` the scope would permit. The call site then reads identically everywhere, inside and out. Non-exported namespace-local helpers stay bare — they have no qualified spelling.
