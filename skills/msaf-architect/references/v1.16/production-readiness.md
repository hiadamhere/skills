# 🚀 Production Readiness (v1.16)

The Workflows runtime, streaming, cancellation, and execution surfaces are byte-identical to v1.15. Use [the v1.15 production guide](../v1.15/production-readiness.md) for the `WatchStreamAsync(blockOnPendingRequest, cancellationToken)` overload, [the v1.14 production guide](../v1.14/production-readiness.md) for the async message-injection and approval-middleware migration checks, and [the v1.13 production guide](../v1.13/production-readiness.md) for run monitoring.

## 🔧 v1.16 operational baseline

- Pin the same MAF version across the agent, abstractions, and workflows packages unless a verified compatibility matrix says otherwise.
- Treat streamed events as the authoritative run lifecycle. Distinguish completion, cancellation, failure, pending human input, and incomplete output collection.
- Carry the host cancellation token through workflow runs, agent calls, mode changes, and message-injection operations.
- Keep tool approval decisions observable and auditable without logging secrets or full sensitive arguments.
- Record the package version, workflow identity, run identity, agent identity, executor name, superstep, duration, and terminal status in telemetry.
- Make retries idempotent at side-effect boundaries. A workflow retry must not silently duplicate an email, payment, deployment, or data mutation.

## ⚗️ Experimental surface in production

v1.16's Magentic prompt customization is gated behind the `MAAI001` experimental diagnostic (see [Human-in-the-Loop and Routing](hitl-and-routing.md)). Before shipping it:

- Scope the suppression to the project that needs it, never the whole solution.
- Record which experimental APIs a release depends on, so the next MAF upgrade has a known blast radius.
- Keep a non-experimental fallback path if the run is business-critical; an evaluation-only API can change or disappear in a minor release.

## 🧪 Test pyramid

1. Unit-test executor input/output and state changes without a network model where possible.
2. Build the real graph in integration tests so incompatible edges fail early.
3. Exercise streaming status, cancellation, checkpoint/resume, and human-request paths.
4. Compile-test every version-specific snippet against exact `1.16.0` packages.
5. Run a bounded live-model smoke test only after deterministic tests pass.

## ⬆️ Upgrading from v1.15

Nothing was removed or renamed — v1.16 is purely additive over v1.15 by mechanical surface diff. Existing code compiles unchanged.

---
*Verified against MAF v1.16.0 DLL surface (2026-08-01). The Workflows production surface is byte-identical to v1.15 by mechanical diff.*
