# 💾 State and Persistence (v1.17)

The scoped-state, checkpoint-store, and serialization surfaces are byte-identical to v1.16. Use [the v1.15 state guide](../v1.15/state-and-persistence.md) for `CheckpointManager.GetLatestCheckpointAsync` and the resume entry point, and [the v1.13 state guide](../v1.13/state-and-persistence.md) for stores and `ICheckpointStore<T>` implementations.

> [!IMPORTANT]
> `GetLatestCheckpointAsync` returns a **nullable** `CheckpointInfo?` — a session that has never checkpointed yields `null`. Declare the result nullable and branch on it; `CheckpointInfo latest = await …` raises CS8600 and sets up a null dereference at resume. The surface dump shows a non-nullable return because reflection carries no nullable-reference annotations, so this is a compile-test fact in every version from v1.15 onward.

## 🧭 The durable-state contract

1. Decide what belongs in scoped workflow state versus an external store. Checkpoints are for resuming a run, not for being your application database.
2. Persist checkpoints at meaningful recovery boundaries.
3. Save the workflow/package version and application schema version beside the checkpoint identity.
4. On resume, resolve the entry point and validate compatibility before allowing executors or tools to run.
5. Test process restart, duplicate resume, corrupt state, cancellation, and partial side effects.

Treat custom Magentic prompts as deployment configuration: pin the text with the deployment, version it alongside the workflow, and treat a prompt change like any other compatibility question at resume time.

## ✅ Review checklist

- State scope and ownership are documented.
- Checkpoint payloads have a schema/version strategy.
- Resume is idempotent at every external side-effect boundary.
- A session with no checkpoints yet is handled explicitly — the `null` return is branched on, not assumed away.
- Agent-mode access uses the asynchronous contract introduced in v1.14.
- Prompt/configuration drift between the checkpointing process and the resuming process is accounted for.

<!-- shared:workflow-hosting -->
## 🧭 Hosting a workflow as an agent

`WorkflowHostingExtensions.AsAIAgent` (present since v1.10; every parameter optional) turns a `Workflow` into an `AIAgent`, so a host that speaks agents — sessions, `RunAsync`, serialization — can run a graph without knowing it is one. Two facts hold in every verified version:

- **The workflow must speak the chat protocol.** `AsAIAgent` accepts any `Workflow`, but the first `RunAsync` throws an **InvalidOperationException** (*"Workflow does not support ChatProtocol: At least List<ChatMessage> and TurnToken must be supported as input"*) unless the start executor accepts `List<ChatMessage>` and `TurnToken`. A bare `Executor<string, string>` graph fails here; a `BuildSequential` workflow qualifies.
- **Give it an explicit `id`.** Without one the agent gets a fresh identifier per call, and `Name` / `Description` are empty.

Executed against pinned 1.14.0, 1.17.0 and 1.19.0; the signature is identical in every dump from 1.10.0. The v1.19 controls for where a hosted agent's checkpoints live are in [the v1.19 state guide](../v1.19/state-and-persistence.md).
<!-- /shared:workflow-hosting -->

---
*Verified against MAF v1.17.0 DLL surface and compile tests (2026-08-05). The checkpointing surface is byte-identical to v1.16 by mechanical diff; the nullable `CheckpointInfo?` return was confirmed by compile test against the pinned 1.17.0 packages. Workflow-hosting block added 2026-08-27: `AsAIAgent` executed against pinned 1.14.0, 1.17.0 and 1.19.0.*
