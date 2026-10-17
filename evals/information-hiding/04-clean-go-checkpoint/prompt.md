---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Next quarter we want to move consumer checkpoints from a JSON file to SQLite. Before we start: is the storage format actually contained in this package, or is it leaking out somewhere? Here's the package and the one place that uses it.

```go
// Package checkpoint records how far a stream consumer has read, so that a
// restarted consumer resumes where it left off instead of reprocessing.
package checkpoint

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net/url"
	"os"
	"path/filepath"

	"github.com/acme/ingest/internal/atomicfile"
)

// Offsets maps a partition number to the offset of the next record to read
// in that partition. A partition with no entry is read from its beginning.
type Offsets map[int]int64

// Store remembers one consumer group's offsets. It is not safe for
// concurrent use; each consumer process owns its Store.
type Store struct {
	path string
}

// Open returns the Store for group, keeping its data under dir.
func Open(dir, group string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("checkpoint: %w", err)
	}
	return &Store{path: filepath.Join(dir, url.PathEscape(group)+".json")}, nil
}

// Load returns the saved offsets. A group that has never saved gets empty
// Offsets, so a new consumer starts every partition from the beginning.
func (s *Store) Load() (Offsets, error) {
	data, err := os.ReadFile(s.path)
	if errors.Is(err, fs.ErrNotExist) {
		return Offsets{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("checkpoint: %w", err)
	}
	var f file
	if err := json.Unmarshal(data, &f); err != nil {
		return nil, fmt.Errorf("checkpoint: reading %s: %w", s.path, err)
	}
	if f.Version != formatVersion {
		return nil, fmt.Errorf("checkpoint: %s has format version %d, want %d", s.path, f.Version, formatVersion)
	}
	if f.Offsets == nil {
		f.Offsets = Offsets{}
	}
	return f.Offsets, nil
}

// Save replaces the saved offsets with offsets. Once it returns nil they
// survive a crash.
func (s *Store) Save(offsets Offsets) error {
	data, err := json.Marshal(file{Version: formatVersion, Offsets: offsets})
	if err != nil {
		return fmt.Errorf("checkpoint: %w", err)
	}
	return atomicfile.WriteFile(s.path, data, 0o644)
}

// file is the on-disk layout. Version lets a later layout be told apart.
type file struct {
	Version int     `json:"version"`
	Offsets Offsets `json:"offsets"`
}

const formatVersion = 1
```

```go
// consumer/run.go
func Run(ctx context.Context, src Source, store *checkpoint.Store, handle func(Record) error) error {
	offsets, err := store.Load()
	if err != nil {
		return err
	}
	for _, p := range src.Partitions() {
		if err := src.Seek(p, offsets[p]); err != nil {
			return err
		}
	}
	tick := time.NewTicker(10 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return store.Save(offsets)
		case <-tick.C:
			if err := store.Save(offsets); err != nil {
				return err
			}
		case rec := <-src.Records():
			if err := handle(rec); err != nil {
				return err
			}
			offsets[rec.Partition] = rec.Offset + 1
		}
	}
}
```
