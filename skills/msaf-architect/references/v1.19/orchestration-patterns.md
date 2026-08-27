# 🕸️ Orchestration Patterns (v1.19)

The orchestration surface is **byte-identical to v1.18** by mechanical diff — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, the group-chat managers, and `MagenticWorkflowBuilder` are all unchanged. Use [the v1.11 orchestration guide](../v1.11/orchestration-patterns.md) as written.

That includes the traps, which are unchanged in v1.19:

<!-- shared:orchestration-traps -->
- **`BuildConcurrent`'s aggregator is optional** despite reading as required in the surface dump.
- **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — go through `AgentWorkflowBuilder.CreateGroupChatBuilderWith`.
- **`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` both exist and both work**; the facade returns the non-`s` one.
<!-- /shared:orchestration-traps -->

Three facts sit next to this layer rather than in it:

- A `BuildSequential` workflow **speaks the chat protocol**, which is what `AsAIAgent` requires to host one as an agent (executed; the other builders were not run through `AsAIAgent`). A hand-built graph over a bare `Executor<string, string>` does not qualify — see [State and Persistence](state-and-persistence.md).
- A participant built with `AllowConcurrentInvocation = true` (v1.18; see [Agent Layer Core](agent-layer-core.md)) runs its own tool calls in parallel *inside* its turn. That does not change the topology's ordering between participants — sequential is still sequential — but it does mean that participant's tools must be safe to run alongside each other.
- A participant whose chat client routes per session (v1.19; see [Agent Layer Core](agent-layer-core.md)) keeps its route for the whole orchestration, because the route is stored in *that participant's* session.

For the manager-led topology see [Human-in-the-Loop and Routing](hitl-and-routing.md); for single-agent iteration see [Agent Loops](agent-loops.md).

---
*Verified against MAF v1.19.0 DLL surface (2026-08-27). The orchestration surface is byte-identical to v1.18 by mechanical diff; the chat-protocol requirement was established by executing `AsAIAgent` over a `BuildSequential` workflow and over a bare executor graph against the pinned 1.19.0 packages.*
