---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Requests with an open-ended range like `Range: bytes=500-` on a 1000-byte file come back with `Content-Range: bytes 500-1000/1000`, and Chrome rejects the response. Fix `ParseRange` and show me the corrected function.

```go
// media/rangehdr.go
package media

import (
	"errors"
	"strconv"
	"strings"
)

var (
	ErrMalformedRange     = errors.New("malformed range header")
	ErrMultipleRanges     = errors.New("multiple ranges not supported")
	ErrUnsatisfiableRange = errors.New("range not satisfiable")
)

const mobileChunk = 1 << 20

// ParseRange parses a single byte range ("bytes=a-b", "bytes=a-", "bytes=-n")
// against a resource of the given size and returns inclusive start and end offsets.
func ParseRange(header string, size int64, capForMobile bool) (start, end int64, err error) {
	if !strings.HasPrefix(header, "bytes=") {
		return 0, 0, ErrMalformedRange
	}
	spec := strings.TrimPrefix(header, "bytes=")
	if strings.Contains(spec, ",") {
		return 0, 0, ErrMultipleRanges
	}
	dash := strings.IndexByte(spec, '-')
	if dash < 0 {
		return 0, 0, ErrMalformedRange
	}
	first, last := strings.TrimSpace(spec[:dash]), strings.TrimSpace(spec[dash+1:])

	switch {
	case first == "":
		n, perr := strconv.ParseInt(last, 10, 64)
		if perr != nil || n <= 0 {
			return 0, 0, ErrMalformedRange
		}
		if n > size {
			n = size
		}
		start, end = size-n, size-1
	case last == "":
		s, perr := strconv.ParseInt(first, 10, 64)
		if perr != nil || s < 0 {
			return 0, 0, ErrMalformedRange
		}
		if s >= size {
			return 0, 0, ErrUnsatisfiableRange
		}
		start, end = s, size
	default:
		s, perr1 := strconv.ParseInt(first, 10, 64)
		e, perr2 := strconv.ParseInt(last, 10, 64)
		if perr1 != nil || perr2 != nil || s < 0 {
			return 0, 0, ErrMalformedRange
		}
		if e >= size {
			e = size - 1
		}
		if s > e {
			return 0, 0, ErrUnsatisfiableRange
		}
		start, end = s, e
	}

	if capForMobile && end-start+1 > mobileChunk {
		end = start + mobileChunk - 1
	}
	return start, end, nil
}
```

```go
// media/serve.go (excerpt)
start, end, err := ParseRange(r.Header.Get("Range"), info.Size(), isMobileUA(r.UserAgent()))
if err != nil {
	w.Header().Set("Content-Range", fmt.Sprintf("bytes */%d", info.Size()))
	http.Error(w, err.Error(), http.StatusRequestedRangeNotSatisfiable)
	return
}
w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, info.Size()))
w.Header().Set("Content-Length", strconv.FormatInt(end-start+1, 10))
w.WriteHeader(http.StatusPartialContent)
f.Seek(start, io.SeekStart)
io.CopyN(w, f, end-start+1)
```
