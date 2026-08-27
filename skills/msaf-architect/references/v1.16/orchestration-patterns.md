# 🕸️ Orchestration Patterns (v1.16)

The **four-topology** orchestration surface is byte-identical to v1.15 by mechanical diff — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, and the group-chat managers are unchanged.

Use [the v1.11 orchestration guide](../v1.11/orchestration-patterns.md) as written for those four.

> [!IMPORTANT]
> **The fifth topology is the exception.** `MagenticWorkflowBuilder` — reachable from the same facade via `CreateMagenticBuilderWith` — gains `WithPromptOverrides` and `WithResponseLanguage` in v1.16, both behind `MAAI001` — a compile **error**, not a warning, until suppressed with `<NoWarn>`. The v1.11 guide predates them. See [Human-in-the-Loop and Routing](hitl-and-routing.md).

The v1.11 guide's traps are unchanged in v1.16:

<!-- shared:orchestration-traps -->
- **`BuildConcurrent`'s aggregator is optional** despite reading as required in the surface dump.
- **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — go through `AgentWorkflowBuilder.CreateGroupChatBuilderWith`.
- **`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` both exist and both work**; the facade returns the non-`s` one.
<!-- /shared:orchestration-traps -->

For the manager-led topology see [Human-in-the-Loop and Routing](hitl-and-routing.md); for single-agent iteration see [Agent Loops](agent-loops.md).

---
*Verified against MAF v1.16.0 DLL surface (2026-08-10). The four-topology orchestration surface is byte-identical to v1.15 by mechanical diff; `MagenticWorkflowBuilder` is the sole delta and gains two methods.*
