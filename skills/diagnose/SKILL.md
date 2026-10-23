---
name: diagnose
description: "Use when the user describes a design symptom and says they don't know what kind of problem it is or which review to run (\"something about this is off but I can't tell what\", \"where do I even start with this?\"). Routes the symptom to the right Plumbline lens with a decision tree and says when there is no structural problem. When the symptom already points at one lens (a naming struggle, error-handling sprawl, a change that touches many files), use that lens directly. Not for a panic, a stack trace, or a failing test (use fault-locality). Not for a comprehensive review (use design-review) or a checklist scan (use red-flags)."
argument-hint: "[description of the symptom or problem]"
allowed-tools: Read, Grep
---

# Diagnose

When invoked with $ARGUMENTS, match the described symptom against the decision tree below and route to the appropriate skill. If code paths are referenced, read them first to confirm the match before routing. This skill routes to other skills from Plumbline (https://github.com/tomymaritano/plumbline). It works best when the full collection is installed.

## Decision Tree

### 0. "It panics / the test is red / here is the stack"

The report is a wrong output, a panic, or a failing test. The question is where it may be fixed.

→ **fault-locality**: Name the function that made the bad value. Do not route this to a design lens.

### 1. "Something feels wrong but I can't say what"

The symptom is a general sense of unease with no concrete complaint.

→ **complexity-recognition**: Apply the three-symptom framework to locate the source.

### 2. "Simple changes require edits in many files"

Change amplification. Branch by cause:

- Shared knowledge is scattered across modules → **information-hiding** (look for leaked implementation details)
- Old abstractions no longer fit the current shape of the system → **code-evolution** (check whether the design has kept pace with requirements)
- Module boundaries cut across concerns instead of encapsulating them → **module-boundaries** (re-evaluate decomposition)

### 3. "This interface is awkward / too many parameters"

The interface exposes too much or forces callers to assemble details they shouldn't need.

- Implementation burden leaks upward → **pull-complexity-down** (push details below the interface)
- The abstraction mixes general infrastructure with special-case logic → **general-vs-special** (separate the two)
- The module is shallow. Interface cost rivals implementation cost → **deep-modules** (deepen the module)

### 4. "I can't name this thing"

Naming difficulty signals a design problem, not a vocabulary problem.

→ **naming-obviousness**: If the name can't be made obvious, the entity's responsibility is likely unclear.
→ Then **design-it-twice**: Consider alternative decompositions that yield nameable pieces.

### 5. "Errors everywhere / too many exceptions"

Exception surfaces are large, catch blocks are boilerplate or error paths obscure the normal path.

→ **error-design**: Apply define-errors-out and exception aggregation.

### 6. "Layers feel redundant / wrappers add nothing"

Pass-through methods, thin adapter classes or layers that exist only for "architecture."

→ **abstraction-quality**: Evaluate whether each layer provides a meaningful abstraction or just adds indirection.

### 7. "Comments are useless / missing / stale"

Comments restate code, are absent where needed or have drifted from the implementation.

→ **comments-docs**: Apply the four-category framework and contamination checks.

### 8. "Code was written under pressure"

Technical debt from tactical shortcuts. The concern is process, not a specific structural flaw.

→ **strategic-mindset**: Assess the tactical-vs-strategic balance.
→ Then **code-evolution**: Plan incremental improvement alongside current work.

### 9. "I know what's wrong, just fix it"

A review already named the problems (a red-flags or design-review report in the conversation, or findings the user lists) and the user wants the code changed.

→ **apply-fixes**: Apply the findings one at a time, with the tests run after each.

## Multiple Symptoms

When the description maps to more than one root symptom, prioritize in this order:

1. **Structural** (symptoms 1–6): These address the shape of the code and have the highest design leverage.
2. **Process** (symptom 8): This addresses how work is done. Important but downstream of structure.
3. **Surface** (symptom 7): Comment/doc issues are often symptoms of deeper structural problems. Fixing structure first may resolve them.

Route to the highest-priority match first. Mention the secondary matches so the user can follow up.

## When There Is No Problem

A vague complaint doesn't mean the code is wrong. Before routing, read the code. If it shows none of the symptoms in the tree (changes stay local, names fit, errors are handled where they belong, interfaces are simple), lead with that verdict: the design is sound. Then, if useful, say what the unease probably is instead (unfamiliar domain, a hard problem, a style preference) and offer at most one optional improvement, labeled as optional. Don't go looking for "what's bugging you" until you find something to restructure.

## Fallback

If the described symptom does not match any branch above, and the code does show concrete problems, fall back to **red-flags**: a systematic scan will surface concrete signals to diagnose from.
