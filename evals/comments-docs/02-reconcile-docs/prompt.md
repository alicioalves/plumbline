---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I just finished writing the doc comments for this Go package before handing it to the platform team. Can you review the comments and tell me what to fix?

```go
// Package replicas keeps the running replicas of each service in line with its spec.
package replicas

import (
	"context"
	"log"
	"time"
)

// Spec describes the desired state.
type Spec struct {
	// Service is the service.
	Service string
	// Image is the image.
	Image string
	// Replicas is the number of replicas.
	Replicas int
	// MaxSurge is the max surge.
	MaxSurge int
	// DrainTimeout is the drain timeout.
	DrainTimeout int
}

// Controller is the controller.
type Controller struct {
	runtime Runtime
	log     *log.Logger
}

// Reconcile reconciles the service. It lists the current replicas and, if there
// are fewer than spec.Replicas, starts new ones, unless the image has changed, in
// which case it first starts up to MaxSurge replicas with the new image (or one if
// MaxSurge is zero, unless the service is a singleton, in which case it drains the
// old replica first), then waits for them to become healthy, except when dryRun is
// set, where it only logs what it would do but still drains if force is also true.
// If there are more replicas than desired it drains the oldest ones first, unless
// some are still starting, in which case it drains the newest. The returned bool is
// true if anything changed, or in dry-run mode if anything would have changed; the
// error is nil even if some replicas failed to start, which are instead reported on
// events if it is non-nil.
func (c *Controller) Reconcile(ctx context.Context, spec Spec, dryRun, force bool, events chan<- Event) (bool, error) {
	current, err := c.runtime.List(ctx, spec.Service)
	if err != nil {
		return false, err
	}
	changed := false

	stale := filter(current, func(r Replica) bool { return r.Image != spec.Image })
	if len(stale) > 0 {
		surge := spec.MaxSurge
		if surge == 0 {
			surge = 1
		}
		if spec.Replicas == 1 {
			if !dryRun || force {
				c.drain(ctx, stale[0], spec.DrainTimeout)
			}
			surge = 1
		}
		for i := 0; i < surge && i < len(stale); i++ {
			changed = true
			if dryRun {
				c.log.Printf("would start %s with %s", spec.Service, spec.Image)
				continue
			}
			c.startAndWait(ctx, spec, events)
		}
		return changed, nil
	}

	switch {
	case len(current) < spec.Replicas:
		for i := len(current); i < spec.Replicas; i++ {
			changed = true
			if dryRun {
				c.log.Printf("would start %s with %s", spec.Service, spec.Image)
				continue
			}
			c.startAndWait(ctx, spec, events)
		}
	case len(current) > spec.Replicas:
		victims := oldestFirst(current)
		if anyStarting(current) {
			victims = newestFirst(current)
		}
		for _, r := range victims[:len(current)-spec.Replicas] {
			changed = true
			if dryRun && !force {
				c.log.Printf("would drain %s", r.ID)
				continue
			}
			c.drain(ctx, r, spec.DrainTimeout)
		}
	}
	return changed, nil
}

// startAndWait starts and waits.
func (c *Controller) startAndWait(ctx context.Context, spec Spec, events chan<- Event) {
	r, err := c.runtime.Start(ctx, spec.Service, spec.Image)
	if err == nil {
		err = c.runtime.WaitHealthy(ctx, r, 2*time.Minute)
	}
	if err != nil && events != nil {
		events <- Event{Service: spec.Service, Err: err}
	}
}

// drain drains the replica.
func (c *Controller) drain(ctx context.Context, r Replica, timeout int) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(timeout)*time.Second)
	defer cancel()
	if err := c.runtime.Drain(ctx, r); err != nil {
		c.log.Printf("drain %s: %v", r.ID, err)
	}
}
```
