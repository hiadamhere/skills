# 💾 State and Persistence (v1.16)

The scoped-state, checkpoint-store, and serialization surfaces are byte-identical to v1.15. Use [the v1.15 state guide](../v1.15/state-and-persistence.md) for `CheckpointManager.GetLatestCheckpointAsync` and the resume entry point, and [the v1.13 state guide](../v1.13/state-and-persistence.md) for stores and `ICheckpointStore<T>` implementations.

> [!IMPORTANT]
> `GetLatestCheckpointAsync` returns a **nullable** `CheckpointInfo?` — a session that has never checkpointed yields `null`. Declare the result nullable and branch on it; `CheckpointInfo latest = await …` raises CS8600 and sets up a null dereference at resume. The surface dump shows a non-nullable return because reflection carries no nullable-reference annotations, so this is a compile-test fact in every version from v1.15 onward.

## 🔄 State design in v1.16

- Choose the narrowest state scope that matches ownership. Avoid using shared workflow state as an implicit message bus.
- Queue state updates through the workflow context so they participate in the runtime's superstep and checkpoint semantics.
- Store identifiers and durable domain data, not live clients, delegates, streams, or other process-bound objects.
- Version serialized state deliberately. A deploy that changes a payload shape must either migrate older checkpoints or reject them with a clear compatibility error.
- Keep secrets out of checkpoints unless the store provides the required encryption, access control, retention, and deletion guarantees.

## ⚙️ Checkpoint and resume lifecycle

1. Select or implement a checkpoint store with explicit durability and concurrency guarantees.
2. Persist checkpoints at meaningful recovery boundaries.
3. Save the workflow/package version and application schema version beside the checkpoint identity.
4. On resume, resolve the entry point and validate compatibility before allowing executors or tools to run.
5. Test process restart, duplicate resume, corrupt state, cancellation, and partial side effects.

Treat custom Magentic prompts as deployment configuration: pin the text with the deployment, version it alongside the workflow, and treat a prompt change like any other compatibility question at resume time.

## ✅ Review checklist

- State scope and ownership are documented.
- Checkpoint payloads have a schema/version strategy.
- Resume is idempotent at every external side-effect boundary.
- A session with no checkpoints yet is handled explicitly rather than assumed to return one.
- Agent-mode access uses the asynchronous contract introduced in v1.14.
- Prompt/configuration drift between the checkpointing process and the resuming process is accounted for.

---
*Verified against MAF v1.16.0 DLL surface and compile tests (2026-08-05). The Workflows checkpointing surface is byte-identical to v1.15 by mechanical diff; the nullable `CheckpointInfo?` return is a compile-test fact a reflection dump cannot express.*
