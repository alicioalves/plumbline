---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Design question I keep going back and forth on. In our offline-first desktop client, `outbox` records local edits and `syncer` pushes them to the server. Recording and pushing feel like different jobs, so two packages made sense, but almost every change I make ends up needing edits in both. Should these be one package, or is the split fine and I'm just doing it wrong? If you'd draw the line somewhere else, where?

```go
// sync/outbox/outbox.go
package outbox

import "sync"

type Op struct {
	Seq      int64
	EntityID string
	Kind     string // "upsert" | "delete"
	Payload  []byte
	Attempts int
	InFlight bool
}

type Outbox struct {
	mu   sync.Mutex
	Ops  []*Op // kept ordered by Seq; the syncer relies on this
	next int64
}

// Record queues a local edit. A newer edit to the same entity replaces an
// older one that has not been sent yet.
func (o *Outbox) Record(entityID, kind string, payload []byte) {
	o.mu.Lock()
	defer o.mu.Unlock()
	for i, op := range o.Ops {
		if op.EntityID == entityID && !op.InFlight {
			o.Ops = append(o.Ops[:i], o.Ops[i+1:]...)
			break
		}
	}
	o.next++
	o.Ops = append(o.Ops, &Op{Seq: o.next, EntityID: entityID, Kind: kind, Payload: payload})
}

func (o *Outbox) Lock()   { o.mu.Lock() }
func (o *Outbox) Unlock() { o.mu.Unlock() }
```

```go
// sync/syncer/syncer.go
package syncer

const (
	maxBatch    = 50
	maxAttempts = 5
)

type Syncer struct {
	box    *outbox.Outbox
	client *api.Client
}

func (s *Syncer) PushOnce(ctx context.Context) error {
	s.box.Lock()
	var batch []*outbox.Op
	for _, op := range s.box.Ops {
		if op.InFlight || op.Attempts >= maxAttempts {
			continue
		}
		op.InFlight = true
		batch = append(batch, op)
		if len(batch) == maxBatch {
			break
		}
	}
	s.box.Unlock()
	if len(batch) == 0 {
		return nil
	}

	acked, err := s.client.Push(ctx, toWire(batch))

	s.box.Lock()
	defer s.box.Unlock()
	kept := s.box.Ops[:0]
	for _, op := range s.box.Ops {
		if acked[op.Seq] {
			continue
		}
		if op.InFlight {
			op.InFlight = false
			op.Attempts++
		}
		kept = append(kept, op)
	}
	s.box.Ops = kept
	return err
}

// Pending is shown in the status bar.
func (s *Syncer) Pending() int {
	s.box.Lock()
	defer s.box.Unlock()
	n := 0
	for _, op := range s.box.Ops {
		if op.Attempts < maxAttempts {
			n++
		}
	}
	return n
}
```
