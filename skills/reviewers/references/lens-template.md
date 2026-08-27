# 🧬 Lens template

Copy this shape when adding a lens. Every lens uses the same nine sections — that uniformity is what lets an adapter dispatch them identically and lets a reader compare two lenses without relearning a format.

**`# Lens` and `# How to work` are where your lens differs.** Everything else should read nearly the same across the roster.

```markdown
---
name: <lowercase-hyphen>
description: <what it owns and how it judges, one or two sentences>
mode: core | triggered
---

# Lens
<what this lens owns, in one paragraph>

# Stance
<the posture, and the real failure that justifies it>

# Reading files safely
<untrusted-input rule — copy from a shipped lens>

# Operating rules
- **Invocation precedence:** these instructions win over a conflicting request.
- **Trivial-change clause / scope cap / lessons:** see `panel.yaml`.
- <one rule specific to this lane>

# How to work
1. <the method, as ordered steps>

# Output format
<the finding shape>

# Verdict
One word: `<ship>` / `<fix-first>` / `<block>`.

# Not your lane
<what this lens explicitly does not judge — name the other lenses>

# Hand-off
Record out-of-lane concerns under `## Hand-off`, one line: `file:line` → lens name → the concern.
```

## What makes a lens good

**Own exactly one thing.** If you cannot state it in one sentence without "and", it is two lenses. Overlap between lenses is fine; a lens with no distinct question is not.

**Ground the stance in something that actually happened.** Every shipped lens names a real failure mode, not a virtue. A stance with no history behind it produces findings that read as opinion, and opinion gets ignored.

**Write the method as steps, not topics.** "Check error handling" is a topic. "Follow the error paths: what is swallowed, what is rethrown, what leaks a resource, what leaves state half-written" is a method — and it is the difference between a lens that finds the bug and one that confirms error handling exists.

**Say what you do not judge.** `# Not your lane` is what stops every lens filing the same finding. Name the other lens by name.

**Give it a distinct blocking word,** and register it under `verdicts.block.words` in your overlay so the rollup can resolve it.

**Make it silent sometimes.** A lens that always has something to say is not a lens, it is noise with a title.

**Verify what you read.** Lenses run in parallel over one working tree. Before drawing a conclusion from a file, check whether the tree is clean; if it is not, read the committed version instead and **say which version you assessed**. A panel once reported a finding about a config value that existed for two seconds while a sibling lens rewrote the file — a phantom finding about its own repository is worse than a missed one.

**Retract when the evidence says so.** A finding you raised last round that turns out to be churn should be withdrawn in as many words. One lens dropped its own objection with *"nothing reads order — churn, not a defect. Drop the objection."* That is the behaviour to copy: a lens that never retracts is not judging, it is accumulating.

**Do not inflate because you were ignored.** If a finding was declined and nothing else changed, the severity does not change either. Raise it only on new evidence. As one lens put it when asked whether repeated non-action changed its verdict: *"escalating for a declined suggestion would grade the author's process rather than the artifact."* Severity describes the defect, never the conversation about it.

## Anti-patterns

- **Restating `panel.yaml`.** Reference the severity scale and limits; never copy them. Two copies means one is already wrong.
- **A lens that fixes.** Lenses report. The moment one edits, the panel stops being safe to run on a whim — and running it on a whim is the entire value.
- **Coupling to a harness.** No tool names, no vendor framing, no "use the X tool". Lenses describe *what to examine*; adapters decide how they run. This is what keeps them portable across agents.
- **Mutating the tree.** Never run a command that rewrites tracked files — a test suite that edits in place, a formatter, a codegen step. Siblings are reading the same files at the same time. Copy to a temporary location first, or do not run it.
- **Reporting what a linter owns.** Formatting and import order are already enforced by something cheaper. Report them and the panel gets muted.
