---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Since we switched billing-sync to our new `httpx` client, every request fails with `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, even though we set `TimeoutSeconds: 10` and the upstream answers in about 50ms. Can you find the bug and fix it?

```go
// internal/httpx/client.go
package httpx

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Options struct {
	BaseURL        string
	TimeoutSeconds int
	MaxRetries     int
	RetryBackoff   time.Duration
	UserAgent      string
	MaxIdleConns   int
	Insecure       bool
}

type Client struct {
	opts Options
	hc   *http.Client
}

func New(opts Options) *Client {
	tr := &http.Transport{
		MaxIdleConns:    opts.MaxIdleConns,
		TLSClientConfig: &tls.Config{InsecureSkipVerify: opts.Insecure},
	}
	return &Client{
		opts: opts,
		hc:   &http.Client{Transport: tr, Timeout: time.Duration(opts.TimeoutSeconds)},
	}
}

func (c *Client) GetJSON(ctx context.Context, path string, out any) error {
	var lastErr error
	for attempt := 0; attempt <= c.opts.MaxRetries; attempt++ {
		if attempt > 0 {
			select {
			case <-time.After(c.opts.RetryBackoff * time.Duration(attempt)):
			case <-ctx.Done():
				return ctx.Err()
			}
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.opts.BaseURL+path, nil)
		if err != nil {
			return err
		}
		req.Header.Set("User-Agent", c.opts.UserAgent)
		resp, err := c.hc.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		if resp.StatusCode >= 500 {
			resp.Body.Close()
			lastErr = fmt.Errorf("server error: %s", resp.Status)
			continue
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("unexpected status: %s", resp.Status)
		}
		return json.NewDecoder(resp.Body).Decode(out)
	}
	return fmt.Errorf("after %d attempts: %w", c.opts.MaxRetries+1, lastErr)
}
```

```go
// cmd/billing-sync/main.go
func newUpstream() *httpx.Client {
	return httpx.New(httpx.Options{
		BaseURL:        os.Getenv("BILLING_UPSTREAM_URL"),
		TimeoutSeconds: 10,
		MaxRetries:     3,
		RetryBackoff:   200 * time.Millisecond,
		UserAgent:      "billing-sync/1.4",
		MaxIdleConns:   50,
	})
}
```
