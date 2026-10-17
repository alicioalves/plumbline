# Red Flags in Python

The flags in the main checklist are language-neutral. This reference lists the shapes they most often take in Python code, so a scan recognizes them in idiomatic form. Flags not listed here look the same in Python as anywhere else.

A Python idiom is not a red flag by itself. Each shape below is a signal to run the flag's check, not a verdict.

## Structural

### Shallow Module (#1)

- An `ABC` or `Protocol` with exactly one implementation and no second one in sight. Python's duck typing already gives callers the seam; the abstract class adds a file and an indirection without hiding anything.
- A class whose methods are all one-line calls into a single dependency, often named `*Manager`, `*Helper` or `*Service`.
- A `@dataclass` plus a module of free functions that each take it as the first argument and touch one field. The behavior and the data were split, and neither half is deep.

> **Check:** Delete the class and call the dependency directly. If nothing gets harder to understand, the module was shallow.

### Pass-Through Method (#2)

- `def f(self, *args, **kwargs): return self._inner.f(*args, **kwargs)`. Forwarding `*args, **kwargs` hides that the signature is borrowed, so the duplication doesn't even show in the interface.
- `__getattr__` that delegates every unknown attribute to a wrapped object, so the wrapper's real interface is the wrapped object's.
- Decorators that wrap every method of a class to add one behavior (caching, logging) and forward the rest.

> **Check:** Does removing the method lose any behavior? For `**kwargs` forwarding, also ask which keyword arguments the outer layer actually understands.

### Temporal Decomposition (#4)

- Modules named `loader.py`, `transformer.py`, `writer.py` (or `extract`/`transform`/`load`) that each import the same column names, dict keys or file-format constants.

## Boundary

### Information Leakage (#5)

- Module-level globals or class attributes that one module writes and another reads (`settings.CURRENT_TENANT = ...`). Nothing in either signature shows the dependency.
- Two modules that build and parse the same `dict` shape by key name (`row["created_at"]`), with no shared type, `TypedDict` or dataclass that owns the shape.
- `pickle`/`json` written in one module and read in another with the field names repeated in both.

### Overexposure (#6)

- `@property` getter plus `@x.setter` for every field, which exposes the representation exactly as a public attribute would and adds ceremony on top.
- A `@dataclass` (or Pydantic model) with every field public and mutable, passed across a module boundary so callers depend on its full internal layout.
- Functions with many keyword arguments where nearly every caller passes the same values: `def connect(host, port=5432, timeout=30, retries=3, backoff=0.5, ssl=None, pool=None, ...)`.
- Raising a library's exception type (`requests.HTTPError`, `sqlalchemy.exc.*`) out of your module, so callers must import and understand your dependency to handle errors.

### Special-General Mixture (#8)

- A `utils.py` / `helpers.py` / `common.py` with functions that know about specific callers: `format_for_invoice_email()`, `if source == "billing":`.
- A shared function grown a boolean keyword argument used by one call site: `def validate(data, *, partner=False)`.

### Vocabulary Not Owned (#18)

- String constants for the same set of values (`"pending"`, `"paid"`, `"refunded"`) repeated across modules or services instead of one `Enum` owned by the module that defines them.
- Several API clients or CLI commands each mapping the same exception types to the same error codes or exit codes.

## Documentation

### Comment Repeats Code (#9)

- Docstrings that restate the signature: `"""Get the user by id.\n\nArgs:\n    user_id: the user id\n"""` on `def get_user_by_id(user_id)`.

### Implementation Documentation Contaminates Interface (#10)

- A public function's docstring that describes the algorithm, the cache, or which internal helper it calls, instead of what the caller gets.

## Naming & Abstraction

### Vague Name (#11)

- Module-scope `data`, `info`, `result`, `obj`, `item`, `tmp`; functions named `process()`, `handle()`, `do_stuff()`, `run()` on classes that do more than one thing.
- Returning a bare `dict` or `tuple` across a module boundary where a named dataclass would document the shape.

## Process

### Catch-and-Ignore (#17)

- `except Exception: pass` and bare `except:`, which also swallows `KeyboardInterrupt`/`SystemExit` in the bare form.
- `except Exception as e: logger.error(e)` followed by carrying on as if the call succeeded, or `return None` that every caller must now check.
- `contextlib.suppress(Exception)` around more than the one call that is expected to fail.

> **Check:** If the failure is genuinely expected and harmless, can it be defined out of existence instead (a default, an idempotent operation, `dict.get`)? If the swallowing is a deliberate, documented trade-off, mark the flag ACCEPTED rather than TRIGGERED.
