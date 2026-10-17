---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Adding a new setting to this service always feels like more ceremony than it should be. Thoughts on how the config side is set up?

```go
// internal/config/config.go
package config

import (
	"os"
	"strings"
)

type Config struct {
	values map[string]string
}

func Load(path string) (*Config, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	values := map[string]string{}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[strings.TrimSpace(k)] = strings.TrimSpace(v)
	}
	return &Config{values: values}, nil
}

func (c *Config) GetString(key string) (string, bool) {
	v, ok := c.values[key]
	return v, ok
}

func (c *Config) Set(key, value string) {
	c.values[key] = value
}
```

```go
// cmd/orders/main.go
package main

import (
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"example.com/orders/internal/config"
)

func main() {
	cfg, err := config.Load(os.Getenv("ORDERS_CONFIG"))
	if err != nil {
		log.Fatal(err)
	}
	addr, ok := cfg.GetString("http.addr")
	if !ok {
		addr = ":8080"
	}
	if err := run(addr, cfg); err != nil {
		log.Fatal(err)
	}
}

func run(addr string, cfg *config.Config) error {
	db, err := openDB(cfg)
	if err != nil {
		return err
	}
	defer db.Close()
	return http.ListenAndServe(addr, newRouter(db, cfg))
}

func openDB(cfg *config.Config) (*sql.DB, error) {
	dsn, ok := cfg.GetString("db.dsn")
	if !ok {
		return nil, errors.New("db.dsn is required")
	}
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}
	maxConns := 10
	if v, ok := cfg.GetString("db.max_conns"); ok {
		n, err := strconv.Atoi(v)
		if err != nil {
			return nil, fmt.Errorf("db.max_conns: %w", err)
		}
		maxConns = n
	}
	db.SetMaxOpenConns(maxConns)
	return db, nil
}

func newRouter(db *sql.DB, cfg *config.Config) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/orders", newOrdersHandler(db, cfg))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	return mux
}

func newOrdersHandler(db *sql.DB, cfg *config.Config) http.Handler {
	timeout := 5 * time.Second
	if v, ok := cfg.GetString("orders.query_timeout_ms"); ok {
		if ms, err := strconv.Atoi(v); err == nil {
			timeout = time.Duration(ms) * time.Millisecond
		}
	}
	return &ordersHandler{db: db, timeout: timeout}
}
```
