# 🕸️ Orchestration Patterns (v1.17)

The orchestration surface is **byte-identical to v1.16** by mechanical diff — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, the group-chat managers, and `MagenticWorkflowBuilder` are all unchanged. (v1.16 was the release that changed `MagenticWorkflowBuilder`; v1.17 changes nothing.) Use [the v1.11 orchestration guide](../v1.11/orchestration-patterns.md) as written.

That includes the traps, which are unchanged in v1.17:

- **`BuildConcurrent`'s aggregator is optional** despite reading as required in the surface dump.
- **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — go through `AgentWorkflowBuilder.CreateGroupChatBuilderWith`.
- **`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` both exist and both work**; the facade returns the non-`s` one.

For the manager-led topology see [Human-in-the-Loop and Routing](hitl-and-routing.md); for single-agent iteration see [Agent Loops](agent-loops.md).

---
*Verified against MAF v1.17.0 DLL surface (2026-08-10). The orchestration surface is byte-identical to v1.16 by mechanical diff.*
