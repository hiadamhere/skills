# 🕸️ Orchestration Patterns (v1.12)

The orchestration surface is **byte-identical to v1.11** by mechanical diff — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, and the group-chat managers are unchanged. Use [the v1.11 orchestration guide](../v1.11/orchestration-patterns.md) as written.

That includes the traps, which are unchanged in v1.12:

- **`BuildConcurrent`'s aggregator is optional** despite reading as required in the surface dump.
- **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — go through `AgentWorkflowBuilder.CreateGroupChatBuilderWith`.
- **`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` both exist and both work**; the facade returns the non-`s` one.

For single-agent iteration see [Agent Loops](agent-loops.md). Manager-led planning (Magentic) is **not documented before v1.16** — see [the v1.16 routing guide](../v1.16/hitl-and-routing.md).

---
*Verified against MAF v1.12.0 DLL surface (2026-08-08). The orchestration surface is byte-identical to v1.11 by mechanical diff.*
