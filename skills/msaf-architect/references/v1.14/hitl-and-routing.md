# 🔀 Human-in-the-Loop and Routing (v1.14)

The Workflows public API is byte-identical to v1.13. Use [the v1.13 routing guide](../v1.13/hitl-and-routing.md) for typed edges, bindings, fan-out/fan-in, orchestration builders, and `RequestPort` human-in-the-loop patterns.

Human input still uses pending requests and `Run.ResumeAsync`; there is no suspend-by-exception API.

## 🔀 v1.14 routing rules

- Validate every edge as a type contract. Insert a mapping executor when the producer and consumer message types differ.
- Use builder-native fan-out and fan-in so the runtime retains telemetry, ordering, and checkpoint semantics.
- Remember the bulk-synchronous execution barrier: a branch does not run indefinitely ahead of its siblings across supersteps.
- Keep sequential work in one executor when splitting it would add barriers without adding a useful routing, persistence, or ownership boundary.
- Treat conditional routing as a graph decision with explicit outcomes; avoid hiding graph topology in unmanaged tasks inside an executor.

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
- Resume tests use the real pending-request path rather than an invented exception flow.

---
*Verified against MAF v1.14.0 DLL surface (2026-07-22). The Workflows routing and HITL surface is byte-identical to v1.13 by mechanical diff.*
