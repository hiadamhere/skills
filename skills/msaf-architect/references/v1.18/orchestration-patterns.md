# 🕸️ Orchestration Patterns (v1.18)

The orchestration surface is **byte-identical to v1.17** by mechanical diff — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, the group-chat managers, and `MagenticWorkflowBuilder` are all unchanged. Use [the v1.11 orchestration guide](../v1.11/orchestration-patterns.md) as written.

That includes the traps, which are unchanged in v1.18:

<!-- shared:orchestration-traps -->
- **`BuildConcurrent`'s aggregator is optional** despite reading as required in the surface dump.
- **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — go through `AgentWorkflowBuilder.CreateGroupChatBuilderWith`.
- **`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` both exist and both work**; the facade returns the non-`s` one.
<!-- /shared:orchestration-traps -->

One agent-layer change touches orchestration indirectly: a participant built with `AllowConcurrentInvocation = true` (see [Agent Layer Core](agent-layer-core.md)) runs its own tool calls in parallel *inside* its turn. That does not change the topology's ordering between participants — sequential is still sequential — but it does mean that participant's tools must be safe to run alongside each other.

For the manager-led topology see [Human-in-the-Loop and Routing](hitl-and-routing.md); for single-agent iteration see [Agent Loops](agent-loops.md).

---
*Verified against MAF v1.18.0 DLL surface (2026-08-27). The orchestration surface is byte-identical to v1.17 by mechanical diff.*
