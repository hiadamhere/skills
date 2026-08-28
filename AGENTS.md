<!-- journal-protocol v1 -->
## Work Journal Protocol (mandatory for all agents)

Maintain a `JOURNAL.md` at the repo root. It is the session-survival log: any fresh agent
session (Claude Code, Codex, Copilot, anything) must be able to read it and know within
seconds what this project is and what to do next — assume the previous session can be cut
at any moment.

Rules:
1. **On session start**: read `JOURNAL.md` first. The `NEXT` section tells you what to do; confirm or adjust it before any other work.
2. **Log as you work, not at the end** — one line per meaningful event, at minimum: work started ("started issue #5"), work finished ("done: PR #65 merged"), decisions made ("discussed X, chose Y because Z"), and blockers ("blocked on missing API key"). If the session dies right now, the journal must already tell the next agent where things stand.
3. **Keep `NEXT` current**: 1–3 bullets at the very top, updated every time the plan changes. This is the single most important part of the file.
4. **Newest first**: prepend today's entries under a `## YYYY-MM-DD` heading at the top of the history.
5. **Never delete or rewrite history.** If the journal contradicts reality (branch deleted, issue closed elsewhere), append a correction, fix `NEXT`, then proceed.

Format:

```markdown
# Journal

## NEXT
- <the single most important next action>
- <optional second/third>

## 2026-06-11
- 14:32 done: PR #65 merged; discussed pagination approach, chose cursor-based because of large tables
- 13:05 started work on issue #5 (lock mechanism)

## 2026-06-10
- ...
```
