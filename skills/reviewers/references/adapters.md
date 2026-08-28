# 🔌 Running the panel from any harness

The panel is vendor-neutral. Everything carrying judgment lives in `panel.yaml` and `lenses/*.md` — plain YAML and markdown, no tool calls, no vendor syntax. An **adapter** is the thin layer that knows how *one* harness spawns parallel sub-tasks.

An adapter must never restate the roster, the severity scale, the verdict map, or any lens's content. It reads them. If an adapter and the manifest disagree, the manifest wins.

## The contract

1. **Load the panel.** Read the shipped `panel.yaml`, then merge `reviewers.local/panel.local.yaml` over it if present ([resolution order](customizing.md)).

2. **Resolve the scope.** An explicit argument, else uncommitted changes, else the current branch against the default branch. Stop with one line if there is nothing to review. A pull-request reference or a path is turned into a file list first — the PR's changed files, or the tracked and untracked files under the path — and handed to the roster step as explicit changed files; it is never passed to a diff command as if it were a revision.

3. **Build one brief, once.** File list with stat summary, commit messages if a range is in play, branch and base. Every lens gets the *identical* brief. Do not paste the diff — each lens opens the files it needs.

   Put every shared fact in the brief rather than in per-lens prose: the scope, what has already been verified, the severity scale, the verdict vocabulary, `limits`, and `lessons`. Per-lens text should be the lens file plus its focus, nothing more. Fourteen bespoke prompts cost fourteen times what one shared brief does.

   **Run the panel's `facts` once, here.** They are read-only commands declared in the manifest — a gate, a test suite, a lint. Put their output in the brief verbatim, marked as *verified by the adapter*, and tell lenses to judge those results rather than re-run the commands. Author claims stay claims and lenses verify them; adapter-run facts are the one thing a lens may take as given. Without this stage, N lenses each re-derive the same mechanical truth at N times the cost.

   **Apply `limits.scope_cap.on_exceed` when the change is over the cap.** List generated artifacts and exclude them from the count; if still over, declare the overage in the brief and require each lens to say what it did not read; over twice the cap, split by top-level path and run the panel per group. A partial read that is not declared reads as complete.

4. **Select the roster.** Dispatch every lens with `mode: core`. Dispatch a `mode: triggered` lens **only when one of its `triggers` globs matches a changed path** — that is what `triggered` means, and honouring it is the difference between paying for the lenses a change needs and paying for all of them. Skip `mode: disabled` entirely.

   Report the selection: which lenses ran, which were skipped and why. A silently skipped lens is worse than a slow one, because the report still reads as complete.

   `--all` (or equivalent) overrides the triggers and runs the whole roster: correct before a release or a merge, wasteful on a routine change. `--profile <name>` runs a declared profile instead — `quick` for a small edit.

5. **Dispatch.** Pass the lens file's body as the sub-task's instructions, plus the shared brief. Each sub-task must be **self-contained** — it sees none of the parent conversation.

   **Tell each lens which of its own prior findings are claimed fixed, and to verify rather than trust.** Without this a re-run mostly inherits the previous run's conclusions. With it, panels have caught a blocker inside the fix to the previous blocker, a stamp whose reasoning was circular, and a sentence broken by the edit that fixed the sentence before it.

   **No lens may run a command that mutates tracked files** — a test suite that rewrites files in place, a formatter, a build that regenerates sources. Lenses run in parallel and read the same working tree, so one lens's mutation becomes another lens's observation. This is not hypothetical: a panel once read a config file mid-rewrite and reported a finding about state that existed for two seconds. If a lens must run such a command, it copies the inputs to a temporary location first.

6. **Run them in parallel.** Sequential works and is only slower.

7. **Synthesize.** Group by severity, merge duplicates and note which lenses flagged each, resolve `## Hand-off` pointers (merge if the target lens found it independently; otherwise surface it credited to the originator), and roll the verdict up **worst-case-wins**.

   **Report what the run cost.** When the harness exposes per-sub-task usage, put tokens and wall time per lens in the report. The `limits` block is load-bearing only if someone can see the number it is bounding.

   **Surface disagreements; do not quietly pick a side.** When two lenses reach opposite conclusions on the same question — both citing the manifest or a policy correctly — that is a real finding about the change, and it belongs in the report as its own item. It is the author's call, not the synthesizer's. One such disagreement produced a design gap neither lens had named on its own.

8. **Report. Never edit.**

That is the whole contract. Any harness that can spawn a sub-task with a prompt and collect its text can run this panel.

## Writing one

Implement the eight steps in whatever form your harness discovers — a slash command, an `AGENTS.md` section, a CLI entry point, a task definition. Keep it under a page; if it is longer, judgment has leaked out of the lenses and into the adapter.

**Script the deterministic half.** Manifest merge, glob matching, lens-file resolution, verdict-word registration, and the facts run need no judgment — put them in a script the adapter calls, and keep the model for dispatch and synthesis. A model following prose honours a roster or a word budget about as reliably as it honours any other instruction; a script honours it every time, and can be tested.

**Do not copy lens text into the adapter.** That is the single mistake that breaks the design: it creates a second source of truth, and it silently stops your overlay from taking effect.

## Notes for specific harnesses

**Discovery.** Under the Agent Skills standard, skills are found in a project's skills directory, the user's, and the organization's. Your adapter belongs wherever your harness looks for commands — that is normally the only vendor-coupled file in the whole installation.

**Parallelism.** If your harness caps concurrent sub-tasks below the roster size, dispatch in batches rather than trimming the roster. A lens that is silently skipped is worse than one that runs late, because the report still reads as complete.

**No sub-tasks at all?** Run the lenses in sequence in one context, resetting between each so a lens is not influenced by the previous one's findings. You lose independence and speed; the structure still holds.

---
*Reflects official Agent Skills specification (2026-08-27).*
