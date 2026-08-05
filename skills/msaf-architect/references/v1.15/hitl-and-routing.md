# 🔀 Human-in-the-Loop and Routing (v1.15)

The Workflows routing and HITL public API is byte-identical to v1.14. Use [the v1.13 routing guide](../v1.13/hitl-and-routing.md) for typed edges, bindings, fan-out/fan-in, orchestration builders, and `RequestPort` patterns, and [the v1.14 routing guide](../v1.14/hitl-and-routing.md) for the v1.14 routing rules.

Human input still uses pending requests and `Run.ResumeAsync`; there is no suspend-by-exception API.

> [!IMPORTANT]
> v1.15 makes the *streaming* side of a human request explicit: `StreamingRun.WatchStreamAsync(blockOnPendingRequest, cancellationToken)` lets the host decide whether the event stream parks or yields when the run reaches a pending request. See [Production Readiness](production-readiness.md). The request/response contract itself is unchanged.

## 👥 Human-in-the-loop lifecycle

1. An executor creates a request through its `RequestPort`.
2. The host observes the pending request and persists the run identity plus the user-visible decision context.
3. The host validates and records the human response.
4. The run continues through `Run.ResumeAsync` with that response.
5. Cancellation, expiry, duplicate responses, and unauthorized responders are handled as explicit host states.

Do not use `WorkflowSuspendedException`; that type is not part of the shipped API. Do not resume a run from display text alone—bind the response to the stored request and run identity.

## ✅ Review checklist

- All edges are type-compatible at `builder.Build()` time.
- Fan-in behavior is tested with late and failed branches.
- Every human request has authorization, expiry, idempotency, and audit rules.
- The stream's pending-request behavior is chosen deliberately, not inherited by accident.
- Resume tests use the real pending-request path rather than an invented exception flow.

---
*Verified against MAF v1.15.0 DLL surface (2026-08-01). The Workflows routing and HITL surface is byte-identical to v1.14 by mechanical diff.*
