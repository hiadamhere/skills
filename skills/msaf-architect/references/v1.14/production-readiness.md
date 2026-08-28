# 🚀 Production Readiness (v1.14)

The Workflows runtime, event streaming, cancellation, and execution surfaces are byte-identical to v1.13. Use [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring and operational patterns.

When message injection is part of the host, migrate to the asynchronous methods documented in [Agent Layer Core](agent-layer-core.md) and propagate cancellation tokens through every call.

## 🔧 v1.14 operational baseline

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
4. Compile-test every version-specific snippet against exact `1.14.0` packages.
5. Run a bounded live-model smoke test only after deterministic tests pass.

## ⬆️ v1.14 migration checks

- Replace synchronous message-injection calls with `EnqueueMessagesAsync` and `GetPendingMessagesAsync`.
- Pass an `ILoggerFactory` to the renamed approval middleware registrations when you want their diagnostics; the parameter is optional (default `null`), not required.
- Re-evaluate tool auto-approval policies using `ToolAutoApprovalRuleContext`; the wider context is a security feature, not merely a delegate rename.

---
*Verified against MAF v1.14.0 DLL surface and compile tests (2026-08-27). Originally verified 2026-07-22; the optional logger-factory parameter was re-verified by compile test against the pinned 1.14.0 packages on 2026-08-27. The Workflows production surface is byte-identical to v1.13 by mechanical diff.*
