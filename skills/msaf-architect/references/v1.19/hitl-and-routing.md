# 🔀 Human-in-the-Loop and Routing (v1.19)

The typed-edge, binding, fan-out/fan-in, `RequestPort`, and Magentic surfaces are byte-identical to v1.18. Use [the v1.13 routing guide](../v1.13/hitl-and-routing.md) for typed edges, bindings, fan-out/fan-in, orchestration builders, and `RequestPort` patterns, [the v1.14 routing guide](../v1.14/hitl-and-routing.md) for the routing rules, [the v1.15 routing guide](../v1.15/hitl-and-routing.md) for the streaming/pending-request interaction, and [the v1.16 routing guide](../v1.16/hitl-and-routing.md) for Magentic manager prompt customization. The three members v1.19 adds to the Workflows assembly are hosting and checkpoint controls, documented in [State and Persistence](state-and-persistence.md).

> [!WARNING]
> Magentic prompt customization is still gated behind the `MAAI001` experimental diagnostic in v1.19 — it remains a compile **error** until suppressed with `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. Four releases behind an experimental flag is not a promotion signal: treat `MagenticPromptOverrides`, `MagenticDefaultPrompts`, `WithPromptOverrides`, and `WithResponseLanguage` as subject to change, and keep them behind your own seam. The pre-existing builder methods (`AddParticipants`, `WithMaxRounds`, `Build`) are not gated.

## 🔀 Routing rules

- Validate every edge as a type contract. Insert a mapping executor when the producer and consumer message types differ.
- Use builder-native fan-out and fan-in so the runtime retains telemetry, ordering, and checkpoint semantics.
- Remember the bulk-synchronous execution barrier: a branch does not run indefinitely ahead of its siblings across supersteps.
- Treat conditional routing as a graph decision with explicit outcomes; avoid hiding graph topology in unmanaged tasks inside an executor.
- **Routing between chat clients is not graph routing.** v1.19's `RoutePersistingRoutingChatClient` (see [Agent Layer Core](agent-layer-core.md)) chooses which model answers *one agent's* turn, per session; it does not move a message between executors. Use it for cost or capability tiers inside a participant, and edges for topology.

## 🙋 Human-in-the-loop contract

1. Declare a `RequestPort` for the human decision.
2. Run the workflow; a pending request surfaces through `RunStatus.PendingRequests`.
3. Persist the request and run identity, then return control to the host.
4. The run continues through `Run.ResumeAsync` with that response.
5. Cancellation, expiry, duplicate responses, and unauthorized responders are handled as explicit host states.

For Magentic specifically, `RequirePlanSignoff` is the plan-approval gate; do not reimplement it with a custom prompt that merely *asks* the model to wait for approval.

Do not use `WorkflowSuspendedException`; that type is not part of the shipped API. Do not resume a run from display text alone—bind the response to the stored request and run identity.

When the workflow is hosted as an agent (`AsAIAgent`), an interrupted run is continued through the session's `WorkflowSessionCheckpointRecovery` service rather than through `Run.ResumeAsync` — the host resolves the checkpoint, validates it, then calls `TryPrepare`. That service is `MAAI001`-gated and does **not** validate the id it is given; see [State and Persistence](state-and-persistence.md) before relying on it.

## ✅ Review checklist

- All edges are type-compatible at `builder.Build()` time.
- Fan-in behavior is tested with late and failed branches.
- Every human request has authorization, expiry, idempotency, and audit rules.
- The stream's pending-request behavior is chosen deliberately, not inherited by accident.
- Resume tests use the real pending-request path rather than an invented exception flow.
- The host handles an approval request that surfaces after the v1.18 auto-approval cap.
- `MAAI001` suppression is scoped and reviewed, and experimental usage is isolated behind a project seam.
- Overridden prompts are version-pinned and diffed against `MagenticDefaultPrompts` at upgrade time.
- Round/stall bounds remain in place after any `ProgressLedgerPrompt` override.

---
*Verified against MAF v1.19.0 DLL surface and compile tests (2026-08-27). The routing and HITL surface is byte-identical to v1.18 by mechanical diff, and the `MAAI001` gate on the Magentic prompt surface — with the builder methods ungated — was re-confirmed by compile test against the 1.19.0 packages.*
