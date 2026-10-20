---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Our notification dispatcher has become the file nobody wants to touch. It isn't big and nothing in it looks obviously wrong, but it's harder to work with than it should be and newer people keep shipping bugs in it. Can you help me understand why?

```go
// notify/dispatcher.go
package notify

import (
	"errors"
	"fmt"
	"strings"
	"time"
)

type Channel int

const (
	Email Channel = iota
	SMS
	Push
)

var ErrRateLimited = errors.New("notify: rate limited")

type Notification struct {
	Channel  Channel
	UserID   string
	Template string
	Data     map[string]string
	QueuedAt time.Time
}

type Dispatcher struct {
	mailer  Mailer
	sms     SMSGateway
	push    PushService
	limiter *RateLimiter
	tmpl    *TemplateStore
}

func (d *Dispatcher) Validate(n Notification) error {
	switch n.Channel {
	case Email:
		if n.Data["to"] == "" || n.Data["subject"] == "" {
			return errors.New("email requires to and subject")
		}
	case SMS:
		if n.Data["phone"] == "" {
			return errors.New("sms requires phone")
		}
	case Push:
		if n.Data["device_token"] == "" {
			return errors.New("push requires device_token")
		}
	default:
		return fmt.Errorf("unknown channel %d", n.Channel)
	}
	return nil
}

func (d *Dispatcher) render(n Notification) (string, error) {
	body, err := d.tmpl.Render(n.Template, n.Data)
	if err != nil {
		return "", err
	}
	switch n.Channel {
	case Email:
		return body, nil
	case SMS:
		text := stripHTML(body)
		if len(text) > 160 {
			text = text[:157] + "..."
		}
		return text, nil
	case Push:
		return stripHTML(body), nil
	}
	return "", fmt.Errorf("unknown channel %d", n.Channel)
}

func (d *Dispatcher) rateLimitKey(n Notification) string {
	return fmt.Sprintf("%d:%s", n.Channel, strings.ToLower(n.Data["to"]))
}

func (d *Dispatcher) Send(n Notification) error {
	if err := d.Validate(n); err != nil {
		return err
	}
	if !d.limiter.Allow(d.rateLimitKey(n)) {
		return ErrRateLimited
	}
	body, err := d.render(n)
	if err != nil {
		return err
	}
	switch n.Channel {
	case Email:
		return d.mailer.Send(n.Data["to"], n.Data["subject"], body)
	case SMS:
		return d.sms.Send(n.Data["phone"], body)
	case Push:
		title := n.Data["title"]
		if title == "" {
			title = "New notification"
		}
		return d.push.Send(n.Data["device_token"], title, body)
	}
	return fmt.Errorf("unknown channel %d", n.Channel)
}

func (d *Dispatcher) RetryDelay(n Notification, attempt int) time.Duration {
	switch n.Channel {
	case SMS:
		return time.Duration(attempt) * 30 * time.Second
	case Push:
		return 5 * time.Second
	default:
		return time.Duration(attempt*attempt) * time.Minute
	}
}
```

Callers build a `Notification` and call `Send`; the retry worker calls `RetryDelay` when `Send` returns an error other than `ErrRateLimited`.
