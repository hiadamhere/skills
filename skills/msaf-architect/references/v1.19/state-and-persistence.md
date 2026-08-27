# 💾 State and Persistence (v1.19)

The scoped-state, checkpoint-store, and serialization surfaces carry forward from v1.18. Use [the v1.15 state guide](../v1.15/state-and-persistence.md) for `CheckpointManager.GetLatestCheckpointAsync` and the resume entry point, and [the v1.13 state guide](../v1.13/state-and-persistence.md) for stores and `ICheckpointStore<T>` implementations.

> [!IMPORTANT]
> `GetLatestCheckpointAsync` returns a **nullable** `CheckpointInfo?` — a session that has never checkpointed yields `null`. Declare the result nullable and branch on it; `CheckpointInfo latest = await …` raises CS8600 and sets up a null dereference at resume. The surface dump shows a non-nullable return because reflection carries no nullable-reference annotations, so this is a compile-test fact in every version from v1.15 onward.

v1.19 adds three members to the Workflows layer, and all three are about one thing: **a workflow hosted as an agent** and where its checkpoints live.

## 🧭 A workflow as an agent

`WorkflowHostingExtensions.AsAIAgent` (present since v1.10; the rule below is repeated in every version's state guide) turns a `Workflow` into an `AIAgent`, so a host that speaks agents (sessions, `RunAsync`, serialization) can run a graph without knowing it is one:

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
> **Give it an id.** Without one, `AsAIAgent` generates a fresh identifier per call and `Name`/`Description` are empty — and `WithCheckpointing` (below) regenerates an auto-generated id on the copy it returns, while an explicit one is preserved.

## 🆕 Identifying a workflow agent: `WorkflowAgentMetadata`

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

## 🆕 Redirecting checkpoint storage: `WithCheckpointing`

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

## 🧭 The durable-state contract

1. Decide what belongs in scoped workflow state versus an external store. Checkpoints are for resuming a run, not for being your application database.
2. Persist checkpoints at meaningful recovery boundaries — and decide, per hosted workflow agent, whether they live in the session blob or in a `CheckpointManager` you own.
3. Save the workflow/package version and application schema version beside the checkpoint identity.
4. On resume, resolve the entry point and validate compatibility **before** `TryPrepare`; the call itself only checks the id's shape.
5. Test process restart, duplicate resume, corrupt state, cancellation, and partial side effects.

The v1.18 invocable-function bypass (see [the v1.18 agent-layer guide](../v1.18/agent-layer-core.md)) **stores function calls in the agent session** between requests. A session serialized between those two requests carries pending calls that will execute on the next turn — treat that state as part of the session's schema, and expect a resume across a package upgrade to be the moment it matters.

Treat custom Magentic prompts as deployment configuration: pin the text with the deployment, version it alongside the workflow, and treat a prompt change like any other compatibility question at resume time.

## ✅ Review checklist

- Every hosted workflow agent has an explicit id, and `WithCheckpointing` is applied before any wrapper.
- `UsesOwnCheckpointStorage` is asserted where the host expects checkpoints in its own store.
- `CurrentCheckpoint` is declared nullable and branched on; `TryPrepare` is fed only ids that were resolved and validated first.
- A session with no checkpoints yet is handled explicitly — the `null` return of `GetLatestCheckpointAsync` is branched on, not assumed away.
- Sessions that may carry bypassed (stored) function calls are versioned like any other persisted state.
- Prompt/configuration drift between the checkpointing process and the resuming process is accounted for.
- Recovery is exercised on an interrupted run in tests, not only on a finished one.
- State scope and ownership are documented; checkpoint payloads have a schema/version strategy; resume is idempotent at every external side-effect boundary.
- Agent-mode access uses the asynchronous contract introduced in v1.14.

---
*Verified against MAF v1.19.0 DLL surface and compile tests (2026-08-27). `WorkflowAgentMetadata`, `WithCheckpointing`, and `WorkflowSessionCheckpointRecovery` were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0 (CS0246/CS1061). The `MAAI001` split, the optional `AsAIAgent` parameters, the nullable `CurrentCheckpoint` (CS8600), the non-validating `TryPrepare`, the same-instance cases of `WithCheckpointing`, the id regeneration, and the chat-protocol requirement are compile- or execution-test facts a reflection dump cannot express; the `AsAIAgent` hosting facts were additionally executed against pinned 1.14.0 and 1.17.0.*
