---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
The error handling around our feature-flag store is getting out of hand. It feels like half of every caller is try/except. What would you change?

```python
# flags/store.py
import json
import os
import tempfile


class FlagError(Exception):
    pass

class FlagFileMissing(FlagError):
    pass

class FlagFileCorrupt(FlagError):
    pass

class FlagSchemaError(FlagError):
    pass

class FlagNotDefined(FlagError):
    pass

class FlagNotFound(FlagError):
    pass

class FlagAlreadyExists(FlagError):
    pass


class FlagStore:
    def __init__(self, path):
        self.path = path
        self.flags = {}

    def load(self):
        if not os.path.exists(self.path):
            raise FlagFileMissing(self.path)
        try:
            with open(self.path) as f:
                raw = json.load(f)
        except json.JSONDecodeError as e:
            raise FlagFileCorrupt(f"{self.path}: {e}") from e
        if not isinstance(raw, dict) or not isinstance(raw.get("flags"), dict):
            raise FlagSchemaError("top-level 'flags' object required")
        for name, spec in raw["flags"].items():
            if not isinstance(spec, dict) or "enabled" not in spec:
                raise FlagSchemaError(f"flag {name!r} is missing 'enabled'")
        self.flags = raw["flags"]

    def is_enabled(self, name, user_id=None):
        if name not in self.flags:
            raise FlagNotDefined(name)
        spec = self.flags[name]
        if user_id is not None and user_id in spec.get("allow", []):
            return True
        return bool(spec["enabled"])

    def create(self, name, enabled=False):
        if name in self.flags:
            raise FlagAlreadyExists(name)
        self.flags[name] = {"enabled": enabled, "allow": []}
        self._save()

    def remove(self, name):
        if name not in self.flags:
            raise FlagNotFound(name)
        del self.flags[name]
        self._save()

    def _save(self):
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(self.path))
        with os.fdopen(fd, "w") as f:
            json.dump({"flags": self.flags}, f, indent=2)
        os.replace(tmp, self.path)
```

```python
# app/startup.py
def init_flags(app):
    store = FlagStore(app.config["FLAGS_PATH"])
    try:
        store.load()
    except FlagFileMissing:
        log.warning("flag file missing; all flags off")
    except FlagFileCorrupt:
        log.warning("flag file corrupt; all flags off")
    except FlagSchemaError:
        log.warning("flag file invalid; all flags off")
    app.flags = store
```

```python
# checkout/views.py
def checkout(request):
    try:
        use_new_tax = app.flags.is_enabled("new_tax_engine", request.user.id)
    except FlagNotDefined:
        use_new_tax = False
    try:
        express = app.flags.is_enabled("express_pay", request.user.id)
    except FlagNotDefined:
        express = False
    cart = load_cart(request)
    tax = new_tax_engine.compute(cart) if use_new_tax else legacy_tax(cart)
    return render(request, "checkout.html", {"cart": cart, "tax": tax, "express": express})
```

```python
# admin/flags.py
def delete_flag(request, name):
    try:
        app.flags.remove(name)
    except FlagNotFound:
        pass
    return redirect("/admin/flags")


def ensure_flag(name):
    try:
        app.flags.create(name)
    except FlagAlreadyExists:
        pass
```
