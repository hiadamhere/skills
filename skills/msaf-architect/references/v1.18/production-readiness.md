# 🚀 Production Readiness (v1.18)

The Workflows runtime, streaming, cancellation, and execution surfaces are byte-identical to v1.17. Use [the v1.15 production guide](../v1.15/production-readiness.md) for the `WatchStreamAsync(blockOnPendingRequest, cancellationToken)` overload, [the v1.14 production guide](../v1.14/production-readiness.md) for the async message-injection and approval-middleware migration checks, and [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring.

## 🛠️ Operational guidance

- Treat run identity, session identity, and checkpoint identity as three separate things in logs and dashboards. Recovery questions are asked in terms of all three.
- Decide the stream's pending-request behavior deliberately at every host: a request handler or queue worker passes `blockOnPendingRequest: false`; a long-lived interactive host may pass `true`.
- Propagate cancellation from the host edge through the run, the executors, and the wrapped agent calls.
- Emit distinct telemetry for successful completion, pending human request, cancellation, and failure. Collapsing them into "done" makes the pending-request state invisible in production.
- **New in v1.18:** emit a metric when `ToolApprovalAgent` hits its auto-approval cap. That event is the difference between a model that finished and a model that was stopped from looping on an auto-approved tool.
- **New in v1.18:** every host that starts background agents releases the session (`ReleaseSessionAsync`) on conversation end or eviction; otherwise abandoned tasks keep spending model and tool calls. The default waits up to 30 seconds for cancelled tasks — budget for that in shutdown paths.
- **New in v1.18:** treat `AllowConcurrentInvocation = true` as a load-test item, not a flag. Tools that were only ever exercised one at a time have not been exercised at all under this setting.

## ⚗️ Experimental surface in production

The `MAAI001` inventory grows in v1.18. Gated: the Magentic prompt customization from v1.16 (see [Human-in-the-Loop and Routing](hitl-and-routing.md)), the invocable-function bypass (`EnableInvocableFunctionBypassing`, `UseInvocableFunctionBypassing`), and `BackgroundAgentsProvider` including its new `ReleaseSessionAsync`. **Not** gated: `AllowConcurrentInvocation` and `MaxAutoApprovalIterations`. Before shipping anything gated:

- Scope the suppression to the project that needs it, never the whole solution.
- Record which experimental APIs a release depends on, so the next MAF upgrade has a known blast radius.
- Keep a non-experimental fallback path if the run is business-critical; an evaluation-only API can change or disappear in a minor release.

## ✅ Review checklist

- Cancellation is propagated from the host edge to every agent call.
- Pending-request runs are observable as their own state, not folded into failure or success.
- The stream's pending-request behavior is an explicit argument at every call site.
- The auto-approval cap and background-session release are observable in telemetry.
- Experimental (`MAAI001`) usage is inventoried per release and isolated behind a project seam.

## ⬆️ Upgrading from v1.17

Nothing was removed or renamed — v1.18 is purely additive by mechanical surface diff, and the additions are confined to `Microsoft.Agents.AI`: two `ChatClientAgentOptions` flags, one `ToolApprovalAgentOptions` property, one builder extension, and one `BackgroundAgentsProvider` method. `Microsoft.Agents.AI.Abstractions` and `Microsoft.Agents.AI.Workflows` are byte-identical to v1.17. v1.17 code compiles unchanged; adopt the new members only where the behavior they control matters.

---
*Verified against MAF v1.18.0 DLL surface and compile tests (2026-08-27). The five new members were compiled and executed against the pinned 1.18.0 packages and fail to compile against 1.17.0; the `MAAI001` split is a compile-test fact a reflection dump cannot express.*
