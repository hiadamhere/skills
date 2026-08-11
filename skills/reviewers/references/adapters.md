# 🔌 Running the panel from any harness

The panel is vendor-neutral. Everything carrying judgment lives in `panel.yaml` and `lenses/*.md` — plain YAML and markdown, no tool calls, no vendor syntax. An **adapter** is the thin layer that knows how *one* harness spawns parallel sub-tasks.

An adapter must never restate the roster, the severity scale, the verdict map, or any lens's content. It reads them. If an adapter and the manifest disagree, the manifest wins.

## The contract

1. **Load the panel.** Read the shipped `panel.yaml`, then merge `reviewers.local/panel.local.yaml` over it if present ([resolution order](customizing.md)).
2. **Resolve the scope.** An explicit argument, else uncommitted changes, else the current branch against the default branch. Stop with one line if there is nothing to review.
3. **Build one brief, once.** File list with stat summary, commit messages if a range is in play, branch and base. Every lens gets the *identical* brief. Do not paste the diff — each lens opens the files it needs.
4. **Dispatch each rostered lens** whose `mode` is not `disabled`. Pass the lens file's body as the sub-task's instructions, plus the brief, the severity scale, the verdict vocabulary, `limits`, and `lessons`. Each sub-task must be **self-contained** — it sees none of the parent conversation.
5. **Run them in parallel.** Sequential works and is only slower.
6. **Synthesize.** Group by severity, merge duplicates and note which lenses flagged each, resolve `## Hand-off` pointers (merge if the target lens found it independently; otherwise surface it credited to the originator), and roll the verdict up **worst-case-wins**.
7. **Report. Never edit.**

That is the whole contract. Any harness that can spawn a sub-task with a prompt and collect its text can run this panel.

## Writing one

Implement the seven steps in whatever form your harness discovers — a slash command, an `AGENTS.md` section, a CLI entry point, a task definition. Keep it under a page; if it is longer, judgment has leaked out of the lenses and into the adapter.

**Do not copy lens text into the adapter.** That is the single mistake that breaks the design: it creates a second source of truth, and it silently stops your overlay from taking effect.

## Notes for specific harnesses

**Discovery.** Under the Agent Skills standard, skills are found in a project's skills directory, the user's, and the organization's. Your adapter belongs wherever your harness looks for commands — that is normally the only vendor-coupled file in the whole installation.

**Parallelism.** If your harness caps concurrent sub-tasks below the roster size, dispatch in batches rather than trimming the roster. A lens that is silently skipped is worse than one that runs late, because the report still reads as complete.

**No sub-tasks at all?** Run the lenses in sequence in one context, resetting between each so a lens is not influenced by the previous one's findings. You lose independence and speed; the structure still holds.
