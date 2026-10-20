---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I'm taking over this session cache package and I find it hard to follow on first read: I keep having to read every function body to work out what anything is. What would make it clearer?

```go
// sessions/cache.go
package sessions

import (
	"encoding/json"
	"sync"
	"time"
)

type Info struct {
	ID    string
	Uid   string
	Roles []string
}

type entry struct {
	data *Info
	ttl  int64
	flag bool
}

type Config struct {
	TTL      int64
	MaxItems int
}

var (
	mu  sync.Mutex
	m   = map[string]*entry{}
	cfg = Config{TTL: 1800, MaxItems: 10000}
)

func Configure(c Config) {
	mu.Lock()
	defer mu.Unlock()
	cfg = c
}

func Process(d []byte) (*Info, error) {
	var tmp struct {
		Sid   string   `json:"sid"`
		Sub   string   `json:"sub"`
		Roles []string `json:"roles"`
	}
	if err := json.Unmarshal(d, &tmp); err != nil {
		return nil, err
	}
	mu.Lock()
	defer mu.Unlock()
	now := time.Now().Unix()
	if e, ok := m[tmp.Sid]; ok && e.ttl > now {
		e.flag = true
		return e.data, nil
	}
	if len(m) >= cfg.MaxItems {
		sweep(now)
	}
	info := &Info{ID: tmp.Sid, Uid: tmp.Sub, Roles: tmp.Roles}
	m[tmp.Sid] = &entry{data: info, ttl: now + cfg.TTL, flag: true}
	return info, nil
}

func Get(id string) *Info {
	mu.Lock()
	defer mu.Unlock()
	e, ok := m[id]
	if !ok || e.ttl <= time.Now().Unix() {
		return nil
	}
	e.flag = true
	return e.data
}

func Handle(id string) {
	mu.Lock()
	defer mu.Unlock()
	delete(m, id)
}

func ForUser(id string) []*Info {
	mu.Lock()
	defer mu.Unlock()
	var res []*Info
	for _, e := range m {
		if e.data.Uid == id {
			res = append(res, e.data)
		}
	}
	return res
}

func sweep(now int64) {
	for k, e := range m {
		if !e.flag || e.ttl <= now {
			delete(m, k)
			continue
		}
		e.flag = false
	}
}
```
