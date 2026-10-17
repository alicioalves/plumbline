---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Does this interface hold up? It's one function, and I keep going back and forth on whether it should expose more (temp directory, whether to fsync, a writer instead of a byte slice) or whether it's too thin to be its own package at all.

```go
// Package atomicfile replaces files so that readers see either the old
// contents or the new contents, never a partial write, even if the process
// or the machine crashes midway.
package atomicfile

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
)

// WriteFile replaces the file at path with data and sets its permission bits
// to perm (not masked by the umask). Once WriteFile returns nil, the new
// contents are durable. If it returns an error, path holds either the old or
// the new contents, never a mix.
//
// The directory containing path must already exist. Concurrent calls for the
// same path are safe; the last one to finish wins.
func WriteFile(path string, data []byte, perm fs.FileMode) (err error) {
	dir := filepath.Dir(path)
	// The temp file must live in the same directory: rename is only atomic
	// within a single filesystem.
	tmp, err := os.CreateTemp(dir, "."+filepath.Base(path)+".tmp-*")
	if err != nil {
		return fmt.Errorf("atomicfile: %w", err)
	}
	defer func() {
		if err != nil {
			tmp.Close()
			os.Remove(tmp.Name())
		}
	}()

	if _, err = tmp.Write(data); err != nil {
		return fmt.Errorf("atomicfile: writing %s: %w", path, err)
	}
	if err = tmp.Chmod(perm); err != nil {
		return fmt.Errorf("atomicfile: %w", err)
	}
	// Flush the contents before the rename makes them visible; otherwise a
	// crash can leave path naming an empty or partial file.
	if err = tmp.Sync(); err != nil {
		return fmt.Errorf("atomicfile: syncing %s: %w", path, err)
	}
	if err = tmp.Close(); err != nil {
		return fmt.Errorf("atomicfile: %w", err)
	}
	if err = os.Rename(tmp.Name(), path); err != nil {
		return fmt.Errorf("atomicfile: %w", err)
	}
	return syncDir(dir)
}

// syncDir makes a rename within dir durable by flushing the directory entry.
func syncDir(dir string) error {
	if runtime.GOOS == "windows" {
		return nil // Windows cannot fsync a directory handle.
	}
	d, err := os.Open(dir)
	if err != nil {
		return fmt.Errorf("atomicfile: %w", err)
	}
	defer d.Close()
	if err := d.Sync(); err != nil {
		return fmt.Errorf("atomicfile: syncing directory %s: %w", dir, err)
	}
	return nil
}
```

The callers all look like this:

```go
if err := atomicfile.WriteFile(cfgPath, buf, 0o600); err != nil {
	return fmt.Errorf("saving config: %w", err)
}
```
