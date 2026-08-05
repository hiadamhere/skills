# 🚀 Production Readiness (v1.17)

The Workflows runtime, streaming, cancellation, and execution surfaces are byte-identical to v1.16. Use [the v1.15 production guide](../v1.15/production-readiness.md) for the `WatchStreamAsync(blockOnPendingRequest, cancellationToken)` overload, [the v1.14 production guide](../v1.14/production-readiness.md) for the async message-injection and approval-middleware migration checks, and [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring.

## 🛠️ Operational guidance

- Treat run identity, session identity, and checkpoint identity as three separate things in logs and dashboards. Recovery questions are asked in terms of all three.
- Decide the stream's pending-request behavior deliberately at every host: a request handler or queue worker passes `blockOnPendingRequest: false`; a long-lived interactive host may pass `true`.
- Propagate cancellation from the host edge through the run, the executors, and the wrapped agent calls.
- Emit distinct telemetry for successful completion, pending human request, cancellation, and failure. Collapsing them into "done" makes the pending-request state invisible in production.

## ⚗️ Experimental surface in production

The Magentic prompt customization added in v1.16 is **still gated behind `MAAI001` in v1.17** (see [Human-in-the-Loop and Routing](hitl-and-routing.md)). A second release behind the flag is not a promotion signal. Before shipping it:

- Scope the suppression to the project that needs it, never the whole solution.
- Record which experimental APIs a release depends on, so the next MAF upgrade has a known blast radius.
- Keep a non-experimental fallback path if the run is business-critical; an evaluation-only API can change or disappear in a minor release.

## ✅ Review checklist

- Cancellation is propagated from the host edge to every agent call.
- Pending-request runs are observable as their own state, not folded into failure or success.
- The stream's pending-request behavior is an explicit argument at every call site.
- Experimental (`MAAI001`) usage is inventoried per release and isolated behind a project seam.

## ⬆️ Upgrading from v1.16

Nothing was removed, renamed, or added — the entire public surface of `Microsoft.Agents.AI`, `Microsoft.Agents.AI.Abstractions`, and `Microsoft.Agents.AI.Workflows` is byte-identical to v1.16 by mechanical diff. v1.16 code compiles unchanged; there is no adoption work and no migration work at the API level.

---
*Verified against MAF v1.17.0 DLL surface and compile tests (2026-08-05). The v1.15/v1.16 doc patterns were compiled against the pinned 1.17.0 packages.*
