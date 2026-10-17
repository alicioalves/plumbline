# Red Flags in TypeScript

The flags in the main checklist are language-neutral. This reference lists the shapes they most often take in TypeScript and JavaScript code (including React), so a scan recognizes them in idiomatic form. Flags not listed here look the same in TypeScript as anywhere else.

A TypeScript idiom is not a red flag by itself. Each shape below is a signal to run the flag's check, not a verdict. Type-level noise (`any`, missing annotations, lint rules) is not a design flag; leave it out of the report.

## Structural

### Shallow Module (#1)

- An `interface IFooService` with a single `class FooService implements IFooService` and no second implementation in sight. Structural typing already lets tests pass a stand-in; the interface duplicates the class's surface.
- A class with private fields exposed one-for-one through `get`/`set` accessors and no behavior.
- A custom React hook that only wraps one other hook and returns its result unchanged.

> **Check:** Could a caller skip this module and do the work directly with no extra knowledge?

### Pass-Through Method (#2)

- Barrel files (`index.ts`) that re-export everything from many modules, so the package's public surface is every internal file and no module hides anything.
- Prop drilling: a component that accepts props only to hand them to a child, often several levels deep. Each layer pays interface cost for a decision it doesn't make.
- Service methods that are `return this.repo.findById(id)` with the same signature as the repository.
- Wrapper functions that spread arguments through: `(...args: Parameters<typeof fetchUser>) => fetchUser(...args)`.

> **Check:** Does removing the layer lose any behavior? For prop drilling, would context, composition (passing children) or moving state down remove the intermediate props?

### Conjoined Methods (#3)

- A `useEffect` that sets state another `useEffect` reads, where neither makes sense without the other.
- An `init()` that must be called before other methods, with nothing in the type preventing out-of-order calls.

## Boundary

### Information Leakage (#5)

- A response shape declared twice: once as a type on the server, again by hand on the client (or in a test fixture), with no shared package or generated client.
- `as SomeType` casts at a module boundary, where the receiving module asserts it knows the sender's internal shape instead of the sender's interface saying so.
- Two modules that build and parse the same URL, query-string or local-storage key by string concatenation.

### Overexposure (#6)

- Options objects with 10+ optional fields where most callers set the same two or three: `createClient({ baseUrl, timeout, retries, retryDelay, backoff, headers, agent, ... })`.
- Components with long prop lists where most props exist for one call site.
- Exporting a module's internal types or state (a store's whole state shape) so other modules can reach in.

### Repetition (#7)

- The same `try/catch` + toast/log block around every call to one client.
- The same data-fetching + loading + error state boilerplate in every component instead of one hook or loader.

### Special-General Mixture (#8)

- A shared component or util with a boolean prop or parameter used by one caller: `<Button isCheckoutVariant />`, `formatPrice(value, { forInvoice: true })`.

### Vocabulary Not Owned (#18)

- The same string-literal union (`type Status = "pending" | "paid" | "refunded"`) re-declared in several packages or apps instead of imported from the package that owns it.
- Several clients (web, mobile, CLI) each mapping the same API error codes to messages or behavior, with tables that drift.
- Each SDK or adapter re-implementing default values or option merging that the core library should apply.

## Naming & Abstraction

### Vague Name (#11)

- `data`, `info`, `item`, `payload`, `handler`, `manager`, `utils` at module scope; `handleClick` on a component with several clickable things.
- Returning `Record<string, unknown>` or a tuple across a module boundary where a named type would document the shape.

## Process

### Catch-and-Ignore (#17)

- `catch {}` and `catch (e) { console.error(e) }` that carry on as if the call succeeded.
- `.catch(() => {})` or `.catch(() => null)` on a promise, and floating promises (a call that returns a promise with no `await`, `return` or `.catch`), which turn failures into unhandled rejections nobody sees.
- Returning `undefined` from a catch so every caller must now handle a value the type may not even mention.

> **Check:** Can the error be defined out of existence (an idempotent operation, a sensible default, a typed `Result`), or handled once inside the module? If the swallowing is a deliberate, documented trade-off, mark the flag ACCEPTED rather than TRIGGERED.
