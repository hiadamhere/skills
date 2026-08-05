# 🧠 Agent Layer Core (v1.16)

The agent-layer public API is byte-identical to v1.15. Use [the v1.13 agent-layer guide](../v1.13/agent-layer-core.md) for agent construction, sessions, and workflow binding, and [the v1.14 agent-layer guide](../v1.14/agent-layer-core.md) for the asynchronous agent-mode contract (`GetModeAsync` / `SetModeAsync`), asynchronous message injection, and the approval-middleware changes.

## 🛠️ v1.16 engineering guidance

- The v1.14 async migration is still the live one: await mode reads/writes and message injection, and propagate cancellation through both.
- Pin the agent, abstractions, and workflows packages to the same `1.16.0` version; the three ship in lockstep.
- Keep agent identity, session identity, and run identity distinct in logs. Recovery and audit questions are asked in terms of all three.
- An agent passed as a Magentic *manager* is an ordinary `AIAgent`; the orchestration behavior lives in the builder, not in a special agent type.

## ✅ Review checklist

- Mode access and message injection are awaited, with cancellation propagated.
- Session reuse or isolation is intentional at every call site.
- No agent-layer call is assumed synchronous because an older sample showed it that way.

---
*Verified against MAF v1.16.0 DLL surface (2026-08-01). The agent-layer surface is byte-identical to v1.15 by mechanical diff.*
