# 💾 State and Persistence (v1.14)

The workflow state and checkpointing public API is byte-identical to v1.13. Use [the v1.13 state guide](../v1.13/state-and-persistence.md) for scoped state, checkpoint stores, serialization, and resume behavior.

Agent-mode state access is the exception: `AgentModeProvider.GetModeAsync` and `SetModeAsync` are asynchronous in v1.14 and must be awaited. See [Agent Layer Core](agent-layer-core.md).

## 🔄 State design in v1.14

- Choose the narrowest state scope that matches ownership. Avoid using shared workflow state as an implicit message bus.
- Queue state updates through the workflow context so they participate in the runtime's superstep and checkpoint semantics.
- Store identifiers and durable domain data, not live clients, delegates, streams, or other process-bound objects.
- Version serialized state deliberately. A deploy that changes a payload shape must either migrate older checkpoints or reject them with a clear compatibility error.
- Keep secrets out of checkpoints unless the store provides the required encryption, access control, retention, and deletion guarantees.

## ⚙️ Checkpoint and resume lifecycle

1. Select or implement a checkpoint store with explicit durability and concurrency guarantees.
2. Persist checkpoints at meaningful recovery boundaries.
3. Save the workflow/package version and application schema version beside the checkpoint identity.
4. On resume, validate compatibility before allowing executors or tools to run.
5. Test process restart, duplicate resume, corrupt state, cancellation, and partial side effects.

## ⬆️ Agent-mode migration boundary

Workflow scoped-state APIs did not change in v1.14. Agent modes did: await `GetModeAsync` and `SetModeAsync`, propagate cancellation, and do not replace those awaits with blocking synchronous calls. The nested mode record is `AgentModeProviderOptions.AgentMode`, and its instruction text is exposed through `Instructions`.

## ✅ Review checklist

- State scope and ownership are documented.
- Checkpoint payloads have a schema/version strategy.
- Resume is idempotent at every external side-effect boundary.
- Agent-mode access uses the v1.14 asynchronous contract.

---
*Verified against MAF v1.14.0 DLL surface (2026-07-22). The Workflows state and checkpointing surface is byte-identical to v1.13 by mechanical diff.*
