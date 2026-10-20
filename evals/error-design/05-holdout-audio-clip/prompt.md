---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Every tool in our podcast editor that touches a clip ends with the same little dance of `errors.Is` checks, clamping and retrying, and each new tool gets it slightly wrong in its own way. I suspect the `clip` package is reporting things the wrong way. What would you change?

```go
// editor/clip/clip.go
package clip

import "errors"

var (
	ErrOutOfRange    = errors.New("clip: time out of range")
	ErrInvertedRange = errors.New("clip: start after end")
	ErrEmptyRange    = errors.New("clip: empty range")
	ErrFadeTooLong   = errors.New("clip: fade longer than clip")
)

type Clip struct {
	rate    int       // samples per second
	samples []float32 // mono
}

func (c *Clip) DurationMs() int { return len(c.samples) * 1000 / c.rate }

func (c *Clip) index(ms int) int { return ms * c.rate / 1000 }

func (c *Clip) checkRange(startMs, endMs int) error {
	if startMs > endMs {
		return ErrInvertedRange
	}
	if startMs == endMs {
		return ErrEmptyRange
	}
	if startMs < 0 || endMs > c.DurationMs() {
		return ErrOutOfRange
	}
	return nil
}

// Window returns the samples between startMs and endMs.
func (c *Clip) Window(startMs, endMs int) ([]float32, error) {
	if err := c.checkRange(startMs, endMs); err != nil {
		return nil, err
	}
	return c.samples[c.index(startMs):c.index(endMs)], nil
}

// Cut removes the audio between startMs and endMs.
func (c *Clip) Cut(startMs, endMs int) error {
	if err := c.checkRange(startMs, endMs); err != nil {
		return err
	}
	c.samples = append(c.samples[:c.index(startMs)], c.samples[c.index(endMs):]...)
	return nil
}

// FadeOut ramps the last ms milliseconds down to silence.
func (c *Clip) FadeOut(ms int) error {
	if ms > c.DurationMs() {
		return ErrFadeTooLong
	}
	n := c.index(ms)
	tail := c.samples[len(c.samples)-n:]
	for i := range tail {
		tail[i] *= float32(n-i) / float32(n)
	}
	return nil
}
```

```go
// editor/tools.go
func (t *Tools) Waveform(c *clip.Clip, fromMs, widthMs int) []float32 {
	s, err := c.Window(fromMs, fromMs+widthMs)
	if errors.Is(err, clip.ErrOutOfRange) {
		s, _ = c.Window(fromMs, c.DurationMs())
	}
	return s
}

func (t *Tools) CutSelection(c *clip.Clip, sel Selection) {
	start, end := sel.AnchorMs, sel.HeadMs
	if start > end {
		start, end = end, start
	}
	err := c.Cut(start, end)
	switch {
	case errors.Is(err, clip.ErrEmptyRange):
		// nothing selected
	case errors.Is(err, clip.ErrOutOfRange):
		_ = c.Cut(max(start, 0), min(end, c.DurationMs()))
	case err != nil:
		t.status = err.Error()
	}
}

func (t *Tools) TrimSilenceAfter(c *clip.Clip, ms int) {
	if err := c.Cut(ms, c.DurationMs()); err != nil && !errors.Is(err, clip.ErrEmptyRange) {
		t.status = err.Error()
	}
}

func (t *Tools) AutoFade(c *clip.Clip) {
	if errors.Is(c.FadeOut(3000), clip.ErrFadeTooLong) {
		_ = c.FadeOut(c.DurationMs())
	}
}
```
