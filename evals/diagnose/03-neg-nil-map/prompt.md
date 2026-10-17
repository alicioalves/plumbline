---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Our metrics counter panics with `assignment to entry in nil map` the first time anything calls `Track`. Something's off but I can't see it. Can you fix it and show me the corrected code?

```go
// metrics/counter.go
package metrics

import (
	"sync"
	"time"
)

type Sink interface {
	Emit(name string, value int64)
}

type Counter struct {
	mu         sync.Mutex
	counts     map[string]int64
	flushEvery time.Duration
	sink       Sink
	done       chan struct{}
}

func NewCounter(sink Sink, flushEvery time.Duration) *Counter {
	c := &Counter{sink: sink, flushEvery: flushEvery, done: make(chan struct{})}
	go c.loop()
	return c
}

func (c *Counter) Track(name string, n int64) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.counts[name] += n
}

func (c *Counter) flush() {
	c.mu.Lock()
	snapshot := c.counts
	c.counts = make(map[string]int64)
	c.mu.Unlock()
	for name, v := range snapshot {
		c.sink.Emit(name, v)
	}
}

func (c *Counter) loop() {
	t := time.NewTicker(c.flushEvery)
	defer t.Stop()
	for {
		select {
		case <-t.C:
			c.flush()
		case <-c.done:
			c.flush()
			return
		}
	}
}

func (c *Counter) Close() {
	close(c.done)
}
```
