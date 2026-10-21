---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Do these tests earn their keep? Don't add any.

```go
package ledger

import "testing"

func Apply(balance, amount int64) (int64, error) {
	if amount == 0 {
		return balance, nil
	}
	next := balance + amount
	if next < 0 {
		return balance, ErrOverdraft
	}
	return next, nil
}

func TestApply_DebitRejectsOverdraft(t *testing.T) {
	got, err := Apply(100, -150)
	if err != ErrOverdraft {
		t.Fatalf("err = %v, want overdraft", err)
	}
	if got != 100 {
		t.Fatalf("balance = %d, want 100 left unchanged", got)
	}
}

func TestApply_CreditAdds(t *testing.T) {
	got, err := Apply(100, 40)
	if err != nil {
		t.Fatal(err)
	}
	if got != 140 {
		t.Fatalf("balance = %d, want 140", got)
	}
}
```
