# 🚀 Production Readiness (v1.19)

The Workflows runtime, streaming, cancellation, and execution surfaces are byte-identical to v1.18. Use [the v1.15 production guide](../v1.15/production-readiness.md) for the `WatchStreamAsync(blockOnPendingRequest, cancellationToken)` overload, [the v1.14 production guide](../v1.14/production-readiness.md) for the async message-injection and approval-middleware migration checks, [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring, and [the v1.18 production guide](../v1.18/production-readiness.md) for the auto-approval cap, background-session release, and concurrent tool invocation.

## 🛠️ Operational guidance

- Treat run identity, session identity, and checkpoint identity as three separate things in logs and dashboards. Recovery questions are asked in terms of all three.
- Decide the stream's pending-request behavior deliberately at every host: a request handler or queue worker passes `blockOnPendingRequest: false`; a long-lived interactive host may pass `true`.
- Propagate cancellation from the host edge through the run, the executors, and the wrapped agent calls.
- Emit distinct telemetry for successful completion, pending human request, cancellation, and failure. Collapsing them into "done" makes the pending-request state invisible in production.
- **New in v1.19:** record the **active route** on every turn of an agent whose chat client routes per session. Cost, latency, and quality all vary by route; a dashboard that cannot split by it cannot explain either.
- **New in v1.19:** at startup, read `WorkflowAgentMetadata` from every hosted workflow agent and assert `UsesOwnCheckpointStorage` matches what the host believes. A `false` where you expected `true` means checkpoints are in the session blob, not in your store — and `WithCheckpointing` returns the agent *unchanged* when it is behind a wrapper, so this is the check that catches a silent no-op.
- **New in v1.19:** MAF 1.19.0 moves its `Microsoft.Extensions.AI` dependency to 10.9.0 (1.17 and 1.18 referenced 10.7.0). A project that also references `Microsoft.Extensions.AI` directly needs a version of at least 10.9.0 alongside the 1.19.0 packages.

## ⚗️ Experimental surface in production

The `MAAI001` inventory grows again. Gated in v1.19: the Magentic prompt customization from v1.16, the v1.18 invocable-function bypass and `BackgroundAgentsProvider`, and now `RoutePersistingRoutingChatClient` with its options, `WorkflowSessionCheckpointRecovery`, and `FeatureUsage`. **Not** gated: `WorkflowAgentMetadata`, `WithCheckpointing`, `AllowConcurrentInvocation`, `MaxAutoApprovalIterations`. Before shipping anything gated:

- Scope the suppression to the project that needs it, never the whole solution.
- Record which experimental APIs a release depends on, so the next MAF upgrade has a known blast radius.
- Keep a non-experimental fallback path if the run is business-critical; an evaluation-only API can change or disappear in a minor release.
- `FeatureUsage` is documented by the package as infrastructure not intended for applications. If a framework integration in your process appends its token to outbound User-Agent headers, know which destinations receive it.

## ✅ Review checklist

- Cancellation is propagated from the host edge to every agent call.
- Pending-request runs are observable as their own state, not folded into failure or success.
- The stream's pending-request behavior is an explicit argument at every call site.
- The active route is recorded per turn for routed agents; `UsesOwnCheckpointStorage` is asserted at startup for hosted workflow agents.
- Experimental (`MAAI001`) usage is inventoried per release and isolated behind a project seam.

## ⬆️ Upgrading from v1.18

Nothing was removed or renamed — v1.19 is purely additive by mechanical surface diff across all three assemblies: `Microsoft.Agents.AI.Abstractions` gains `FeatureUsage`; `Microsoft.Agents.AI` gains `RoutePersistingRoutingChatClient` and `RoutePersistingRoutingChatClientOptions`; `Microsoft.Agents.AI.Workflows` gains `WorkflowAgentMetadata`, `WorkflowHostingExtensions.WithCheckpointing`, and `WorkflowSessionCheckpointRecovery`. v1.18 code compiles unchanged. The one thing that *does* move under existing code is the transitive `Microsoft.Extensions.AI` version.

---
*Verified against MAF v1.19.0 DLL surface and compile tests (2026-08-27). The six new members were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0; the `MAAI001` split and the dependency versions are compile-test and package-metadata facts a reflection dump cannot express.*
