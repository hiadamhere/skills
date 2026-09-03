# 🧭 Hosting a Workflow as an Agent (v1.20)

A host that speaks agents — sessions, `RunAsync`, serialization — can run a graph without knowing it is one. This page covers turning a `Workflow` into an `AIAgent`, deciding where its checkpoints live, and continuing an interrupted run. For state *inside* a workflow and the checkpoint stores themselves, see [State and Persistence](state-and-persistence.md).

`AsAIAgent` has been present since v1.10. The three members that control checkpoint storage and recovery arrived in **v1.19**.

---

## 🚪 `AsAIAgent`

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

// Signature: AsAIAgent(Workflow workflow, string? id = null, string? name = null, string? description = null,
//                      IWorkflowExecutionEnvironment? executionEnvironment = null,
//                      bool includeExceptionDetails = false, bool includeWorkflowOutputsInResponse = false)
Workflow workflow = AgentWorkflowBuilder.BuildSequential(agents);
AIAgent hosted = workflow.AsAIAgent(id: "triage-wf", name: "Triage");
```

> [!WARNING]
> **The workflow must speak the chat protocol.** `AsAIAgent` accepts any `Workflow`, but the first `RunAsync` throws an **InvalidOperationException** — *"Workflow does not support ChatProtocol: At least List<ChatMessage> and TurnToken must be supported as input"* — unless the start executor accepts `List<ChatMessage>` and `TurnToken`. A graph built from a bare `Executor<string, string>` fails here; a `BuildSequential` workflow qualifies — both executed against 1.14.0, 1.17.0 and 1.19.0 (the other orchestration builders were not run through `AsAIAgent`).
>
> **Give it an id.** Without one, `AsAIAgent` generates a fresh identifier per call and `Name`/`Description` are empty — and `WithCheckpointing` regenerates an auto-generated id on the copy it returns, while an explicit one is preserved.

## 🔍 Identifying a workflow agent: `WorkflowAgentMetadata`

```csharp
WorkflowAgentMetadata? meta = hosted.GetService<WorkflowAgentMetadata>();
if (meta is not null)
{
    // This agent runs a workflow. meta.UsesOwnCheckpointStorage says whether it already
    // writes checkpoints to a CheckpointManager named when it was built.
}
```

- A non-`null` result **is** the identification; `ChatClientAgent` and other agents return `null`. Going through `GetService` means the answer is still found when the agent is wrapped by middleware — a `DelegatingAIAgent` forwards it — which a type test on the agent would miss.
- `UsesOwnCheckpointStorage` is `false` for an agent built with the default environment: its checkpoints stay in memory and **travel inside the serialized session** (in the probe, a one-turn session serialized to roughly 9.8 KB). It is `true` after `InProcessExecution.Default.WithCheckpointing(manager)` was passed as the environment, or on the copy `WithCheckpointing` returns (the same session then serialized to under 0.5 KB — the checkpoints are in the manager).
- Not experimental.

## 🔀 Redirecting checkpoint storage: `WithCheckpointing`

```csharp
CheckpointManager manager = CheckpointManager.CreateInMemory();   // or CreateJson(store, options)
AIAgent durable = hosted.WithCheckpointing(manager);              // a COPY; keep it, do not rebuild per request
```

A host receives a finished agent and must decide where its checkpoints go — something only the host knows. The execution environment is fixed at construction, so the extension returns a **copy** that writes to `manager`, preserving the workflow, an explicit id, name, and description. Executed against the pinned packages, the call returns the **same instance, unchanged**, in three cases:

| Input | Result | Why |
|---|---|---|
| An agent that does not host a workflow | same instance | nothing to redirect |
| A workflow agent whose environment already names a `CheckpointManager` (`UsesOwnCheckpointStorage == true`) | same instance | the builder made an explicit choice |
| A workflow agent **behind a wrapper** (`DelegatingAIAgent`, middleware) | same instance | only the innermost agent can be copied; returning it alone would discard the wrapper |

The third case is a limitation, and it is **silent**: apply `WithCheckpointing` before wrapping, and assert `UsesOwnCheckpointStorage` on the result in a test. Not experimental.

## ⚗️ Continuing from a checkpoint: `WorkflowSessionCheckpointRecovery` (experimental)

> [!WARNING]
> `WorkflowSessionCheckpointRecovery` raises **`MAAI001` as a compile error** until suppressed. The two members above are not gated; this one is.

```csharp
AgentSession session = await durable.CreateSessionAsync();
WorkflowSessionCheckpointRecovery? recovery = session.GetService<WorkflowSessionCheckpointRecovery>();
// null for sessions of non-workflow agents; present on a workflow session even before its first run

CheckpointInfo? current = recovery?.CurrentCheckpoint;          // null until the first run completes a checkpoint
if (recovery is not null && recovery.TryPrepare(checkpointId))   // string?; null keeps the current selection
{
    // The session is positioned to continue the work queued in that checkpoint,
    // without starting a new user turn.
}
```

What the compile and execution tests established:

- **`CurrentCheckpoint` is `CheckpointInfo?`** — `null` before any run has checkpointed. The dump renders a non-nullable `CheckpointInfo`; assigning to one raises **CS8600**. After a run it equals what `CheckpointManager.GetLatestCheckpointAsync(sessionId)` returns for the same session.
- **`TryPrepare` does not check that the id exists.** `TryPrepare("bogus")` returns `true` and makes `"bogus"` the `CurrentCheckpoint`; the failure arrives on the next run as a **KeyNotFoundException** (*"Could not retrieve checkpoint with id …"*). Only the shape is checked: an empty or whitespace id throws an **ArgumentException**. `TryPrepare(null)` returns `false` when nothing is selected and `true` when a current checkpoint exists. Resolve the id from your own store — or from `GetLatestCheckpointAsync` — before preparing.
- It is **recovery of an interrupted run, not rollback.** The package's own documentation says so, and the probe agrees: after a run had *finished*, `TryPrepare` on its checkpoint returned `true` and a message-less `RunAsync(session)` did not return within ten seconds — there was no queued work to continue. Put a deadline `CancellationToken` on the continuation call and log a cancellation with the session and checkpoint ids — nothing else signals that there was nothing to continue. Selecting an older checkpoint can repeat external effects.
- The checkpoint must belong to the same serialized session, workflow definition, and checkpoint store. The service is present on in-memory sessions too (`UsesOwnCheckpointStorage == false`), where the checkpoints live inside the session blob.

**A hosted run is continued through this service, not through `Run.ResumeAsync`.** The `RequestPort` pending-request path in [Human-in-the-Loop and Routing](hitl-and-routing.md) is for a `Workflow` you run directly; once the graph is behind an agent, the host resolves the checkpoint, validates it, then calls `TryPrepare`.

## ⚠️ Adoption traps

<!-- shared:v119-hosting-adoption-traps -->
| Trap | Reality |
| --- | --- |
| Hosting any `Workflow` with `AsAIAgent` | The first `RunAsync` throws unless the start executor accepts `List<ChatMessage>` and `TurnToken` — a bare `Executor<string, string>` graph fails; a `BuildSequential` workflow qualifies (both executed against 1.14.0, 1.17.0 and 1.19.0). |
| Calling `WithCheckpointing` on a wrapped agent, or after the environment already names a manager | It returns the **same instance, unchanged**, in both cases — and for non-workflow agents. Apply it before wrapping and assert `WorkflowAgentMetadata.UsesOwnCheckpointStorage` afterwards. |
| Relying on an auto-generated agent id across `WithCheckpointing` | The copy regenerates an auto id; an explicit `id` passed to `AsAIAgent` is preserved. Pass an explicit `id`. |
| Trusting `TryPrepare` to reject an unknown checkpoint id | It does not check that the id **exists**: any well-formed id returns `true` and is selected, and the next run throws a **KeyNotFoundException**. Only the shape is checked — an empty or whitespace id throws an **ArgumentException**, and `null` keeps the current selection. Resolve and validate the id first; `GetLatestCheckpointAsync` is the shipped lookup. |
| Assigning `CurrentCheckpoint` to a non-nullable `CheckpointInfo` | It is **`CheckpointInfo?`** — `null` before the first run checkpoints. CS8600, exactly as with `GetLatestCheckpointAsync`. |
| Using recovery as rollback | It continues the work *queued* in a checkpoint. On a finished run there is nothing queued: in the probe a message-less `RunAsync(session)` after `TryPrepare` did not return within ten seconds. Put a deadline token on that call. Selecting an older checkpoint can repeat external effects. |
<!-- /shared:v119-hosting-adoption-traps -->

## ✅ Review checklist

- Every hosted workflow agent has an explicit id, and `WithCheckpointing` is applied before any wrapper.
- `UsesOwnCheckpointStorage` is asserted where the host expects checkpoints in its own store.
- `CurrentCheckpoint` is declared nullable and branched on; `TryPrepare` is fed only ids that were resolved and validated first.
- Recovery is exercised on an interrupted run in tests, not only on a finished one, and the continuation call carries a deadline token.
- The hosted workflow's start executor is asserted to speak the chat protocol, in a test rather than at first production run.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). `WorkflowAgentMetadata`, the `AIAgent` extension `WorkflowHostingExtensions.WithCheckpointing`, and `WorkflowSessionCheckpointRecovery` were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0 (CS0246/CS1061). Note the receiver: the *other* `WithCheckpointing`, on `InProcessExecutionEnvironment`, already exists in 1.18 and is the one used in the environment sample above. The `MAAI001` split, the optional `AsAIAgent` parameters, the nullable `CurrentCheckpoint` (CS8600), the non-validating `TryPrepare`, the same-instance cases of `WithCheckpointing`, the id regeneration, and the chat-protocol requirement are compile- or execution-test facts a reflection dump cannot express; the `AsAIAgent` hosting facts were additionally executed against pinned 1.14.0 and 1.17.0. Page created 2026-09-01 by splitting the v1.19 state guide to keep each page inside the per-page budget; the adoption-trap table was relocated from `version-map.md` on the same date, unchanged in substance. No claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
