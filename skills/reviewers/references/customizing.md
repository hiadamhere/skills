# 🎛️ Customizing the panel

The default pack reviews code. The panel itself reviews **whatever you point it at** — specs, infrastructure, migrations, documentation, a design system, a data catalog. Nothing in the machinery assumes source code; only the default lenses do.

Everything here is designed around one rule:

> **Shipped files are replaced on every update. Your files are never touched.**

So you never edit anything under `references/` — you write a *local overlay* beside it. Updating the skill can then never clobber your work, and you never have to merge.

## The two layers

```
skills/reviewers/references/     ← SHIPPED. Replaced on update. Do not edit.
  panel.yaml                        the default roster
  lenses/*.md                       the default lenses

<your project>/reviewers.local/  ← YOURS. Never touched by an update.
  panel.local.yaml                  overrides, additions, removals
  lenses/*.md                       your own lenses
```

If `reviewers.local/` does not exist, the panel runs the defaults. That is the whole fallback.

## Resolution order

1. Read the shipped `panel.yaml`.
2. If `reviewers.local/panel.local.yaml` exists, merge it over the top:
   - **`severity`, `limits`, `lessons`** — replaced wholesale if present.
   - **`verdicts`** — merged per level; your `words` are added to the shipped ones.
   - **`reviewers`** — matched **by `name`**. A matching entry patches the shipped one field by field. A new name is appended. `mode: disabled` disables one without deleting anything.
3. Resolve each lens's `file`: relative to `reviewers.local/` when the entry came from your overlay, relative to `references/` when it came from the shipped roster.

A lens is just a markdown file. There is no schema to satisfy beyond the frontmatter — `name`, `description`, `mode`.

> **Write `disabled`, never `off`.** YAML 1.1 parses `off`, `on`, `yes`, and `no` as *booleans*, so `mode: off` becomes `mode: false` and a comparison against the string `"off"` silently fails — the lens keeps running. The same trap applies to any value you add: quote it, or choose a word that is not a YAML boolean.

## The four things you will actually want

**Disable a lens.**
```yaml
reviewers:
  - name: performance
    mode: disabled
```

**Retune a shipped lens** — keep its file, change when it fires:
```yaml
reviewers:
  - name: security
    mode: core          # was triggered; now always runs
```

**Replace a shipped lens's content** — same name, your file:
```yaml
reviewers:
  - name: docs
    file: lenses/docs.md   # resolved inside reviewers.local/
```

**Add your own** — this is the interesting one:
```yaml
reviewers:
  - name: migrations
    file: lenses/migrations.md
    mode: triggered
    owns: Reversibility and lock duration of every schema change.
    triggers: ["**/migrations/**", "**/*.sql"]
```

Write `reviewers.local/lenses/migrations.md` following [the lens template](lens-template.md). No code changes, no registration anywhere else — the roster *is* the registration.

## Pointing it at something other than code

Three moves, all in the overlay:

1. **Turn off what does not apply.** Reviewing a spec repository? `performance` and `security` are usually noise — `mode: disabled`.
2. **Add lenses that carry your rules.** The most valuable lens is one that encodes a mistake your team has actually made. A lens grounded in a real incident finds things; a lens written from first principles produces plausible commentary.
3. **Point `lessons` at your own history** — post-mortems, ADRs, incident notes. Every lens reads these *before* hunting new findings, which is what stops the panel rediscovering a defect you already paid for.

```yaml
lessons:
  - path: docs/post-mortems/
    description: What has actually bitten us.
```

## Verdicts and severity

The rollup is **worst-case-wins**: one `block` outranks every approval. This is deliberate and you should think hard before changing it — averaging or majority voting dilutes the single specialist who saw what nobody else was looking for, which is the entire reason for running more than one lens.

If you add a lens with a new blocking word, register it so the rollup can resolve it:

```yaml
verdicts:
  block:
    words: [irreversible]     # appended to the shipped list
```

## Keeping the panel worth running

Two failure modes end with the panel being ignored, and both are yours to avoid:

- **A lens that never returns its one-line acknowledgement is not scoped** — it is a second opinion on everything, and it will be tuned out within a week. Give every lens a shape of change it says nothing about.
- **Removing the cost controls to be "more thorough"** makes the panel expensive, which makes it skipped, which makes it catch nothing. `limits` in `panel.yaml` is load-bearing.

## Checking your overlay

Before relying on it, confirm: the merged roster is what you expect, each lens file resolves, any new verdict word appears in `verdicts`, and a deliberately trivial change still produces one-line acknowledgements. If a lens you disabled still reports, the overlay is not being read — check the path and the `name` match.
