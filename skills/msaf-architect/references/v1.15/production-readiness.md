# 🚀 Production Readiness (v1.15)

The Workflows runtime, cancellation, and execution surfaces carry forward from v1.13. Use [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring and operational patterns, and [the v1.14 production guide](../v1.14/production-readiness.md) for the async message-injection and approval-middleware migration checks.

v1.15 adds one member here: a second `WatchStreamAsync` overload on `StreamingRun`.

## 🆕 Choosing the stream's behavior at a pending request

```csharp
using Microsoft.Agents.AI.Workflows;

StreamingRun run = await InProcessExecution.RunStreamingAsync(workflow, "My message", sessionId, cancellationToken);

await foreach (WorkflowEvent evt in run.WatchStreamAsync(blockOnPendingRequest: false, cancellationToken))
{
    // ...
}
```

Both forms are available in v1.15:

| Call | Behavior |
|---|---|
| `run.WatchStreamAsync(cancellationToken)` | The v1.13 form, unchanged. |
| `run.WatchStreamAsync(blockOnPendingRequest, cancellationToken)` | Explicitly controls whether the stream blocks when the run reaches a pending human request. |

- The `CancellationToken` is **optional** on the new overload — `run.WatchStreamAsync(blockOnPendingRequest: true)` compiles.
- Pass `false` when the host must observe the pending request and return control (a web request handler, a queue worker, any process that cannot sit inside an `await foreach` while a human decides). The host then persists the run identity and resumes later — see [Human-in-the-Loop and Routing](hitl-and-routing.md).
- Pass `true` for a long-lived interactive host that intends to keep the stream open across the human turn.
- Choose it deliberately rather than relying on the default. Whether a stream parks or yields at a human request is a hosting decision, and it is now expressible in the call.

## 🔧 v1.15 operational baseline

- Pin the same MAF version across the agent, abstractions, and workflows packages unless a verified compatibility matrix says otherwise.
- Treat streamed events as the authoritative run lifecycle. Distinguish completion, cancellation, failure, pending human input, and incomplete output collection.
- Carry the host cancellation token through workflow runs, agent calls, mode changes, and message-injection operations.
- Keep tool approval decisions observable and auditable without logging secrets or full sensitive arguments.
- Record the package version, workflow identity, run identity, agent identity, executor name, superstep, duration, and terminal status in telemetry.
- Make retries idempotent at side-effect boundaries. A workflow retry must not silently duplicate an email, payment, deployment, or data mutation.

## 🧪 Test pyramid

1. Unit-test executor input/output and state changes without a network model where possible.
2. Build the real graph in integration tests so incompatible edges fail early.
3. Exercise streaming status, cancellation, checkpoint/resume, and human-request paths.
4. Compile-test every version-specific snippet against exact `1.15.0` packages.
5. Run a bounded live-model smoke test only after deterministic tests pass.

## ⬆️ Upgrading from v1.14

Nothing was removed or renamed — v1.15 is purely additive over v1.14 by mechanical surface diff. Existing calls compile unchanged; adopt the new overload only where the pending-request behavior matters.

---
*Verified against MAF v1.15.0 DLL surface and compile tests (2026-08-01). The remaining Workflows production surface is byte-identical to v1.14 by mechanical diff.*
