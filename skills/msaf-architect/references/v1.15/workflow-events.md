# 📡 Workflow Events (v1.15)

The workflow event taxonomy is **identical to v1.11** by mechanical surface diff — all 21 types, unchanged across v1.11–v1.19.

Use [the v1.11 events guide](../v1.11/workflow-events.md) as written: `InProcessExecution.RunStreamingAsync` hands you a `StreamingRun`, `WatchStreamAsync()` yields the events, and which type arrives tells you what happened.

The v1.11 guide's traps are unchanged in v1.15:

<!-- shared:events-traps -->
> [!WARNING]
> **Three things about this hierarchy will bite you.**
>
> 1. **`WorkflowOutputEvent` must be the LAST case in a `switch`.** `AgentResponseEvent` and `AgentResponseUpdateEvent` derive from it, so a `case WorkflowOutputEvent` placed above them swallows both — and it compiles, because it is a legal pattern order. You get "no agent responses" and nothing to explain it.
> 2. **The Magentic events are in a different namespace.** `MagenticPlanCreatedEvent`, `MagenticReplannedEvent` and `MagenticProgressLedgerUpdatedEvent` live in `Microsoft.Agents.AI.Workflows.Specialized.Magentic`, not `Microsoft.Agents.AI.Workflows`. Without that second `using` they are simply **CS0246 — not found**, which reads as "this version doesn't have them" rather than "you're missing an import".
> 3. **The failure payload is spelled two different ways.** `ExecutorFailedEvent` exposes its exception as **`Data`** (shadowing the base `object Data` with an `Exception`); `WorkflowErrorEvent` exposes its as **`Exception`**. Reaching for `.Exception` on the executor event, or `.Data` on the error event and expecting an exception, is the natural mistake in both directions.
<!-- /shared:events-traps -->

For the run/resume mechanics see [State and Persistence](state-and-persistence.md); for `RequestInfoEvent` and the pause-for-human path see [Human-in-the-Loop and Routing](hitl-and-routing.md).

---
*Verified against MAF v1.15.0 DLL surface (2026-08-12). The 21-type event set is identical across v1.11–v1.19 by mechanical diff (range extended to v1.19 on 2026-08-27); the probe behind the v1.11 guide compiles unmodified against pinned 1.11.0, 1.14.0 and 1.17.0.*
