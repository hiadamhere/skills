# 💾 Workflow State and Persistence (v1.20)

Scoped state inside a running workflow, and the checkpoint stores that let a run survive a process. Running a *workflow as an agent* — `AsAIAgent`, checkpoint redirection, and continuing an interrupted run — is in [Workflow Hosting](workflow-hosting.md).

The scoped-state, checkpoint-store, and serialization surfaces are byte-identical from v1.15 through v1.20 by mechanical diff.

---

## 🔄 The scoped state model

State is separated into scopes so executor contexts stay isolated and keys cannot collide. Access is through the `IWorkflowContext` handed to `HandleAsync`.

### Reading

```csharp
public override async ValueTask<ProcessResult> HandleAsync(
    string message,
    IWorkflowContext context,
    CancellationToken ct)
{
    // Read state from a specific executor scope
    var config = await context.ReadStateAsync<RunConfig>("run-config", "scope-name", ct);

    // Read or initialize if not found (atomic)
    var tracker = await context.ReadOrInitStateAsync<ProgressTracker>(
        "progress",
        () => new ProgressTracker(),
        "scope-name",
        ct);

    return new ProcessResult(tracker.Step);
}
```

### Writing

Updates are **queued** during executor execution and committed atomically at the synchronization barrier, which is what keeps supersteps deterministic:

```csharp
public override async ValueTask<OutputMessage> HandleAsync(
    InputMessage message,
    IWorkflowContext context,
    CancellationToken ct)
{
    // Queue a direct value update for the next superstep
    var nextProgress = new ProgressTracker { Step = 2 };
    await context.QueueStateUpdateAsync("progress", nextProgress, "scope-name", ct);

    // Clear a scope completely
    await context.QueueClearScopeAsync("scope-name", ct);

    return new OutputMessage("Update queued.");
}
```

> [!IMPORTANT]
> A queued update is **not visible to a read in the same superstep**. That is the point of the barrier — an executor reads the state as it was at the start of the step. Code that queues a write and then reads the same key expecting the new value is reading the old one, and nothing reports it.

## 🗄️ Checkpoint stores

> [!WARNING]
> There is **no `IWorkflowStateStore` / `WorkflowState` abstraction and no `Microsoft.Agents.AI.Workflows.State` namespace** in any MAF version — those appear in some stale tutorials but were never shipped. Custom persistence is implemented through `ICheckpointStore<T>`, below.

Checkpointing lives in `Microsoft.Agents.AI.Workflows.Checkpointing` and is coordinated by `CheckpointManager`:

* **In-memory:** `CheckpointManager.CreateInMemory()` — ideal for tests.
* **JSON:** `CheckpointManager.CreateJson(ICheckpointStore<JsonElement> store, JsonSerializerOptions options)`.
* **Default:** `CheckpointManager.Default`.

MAF ships a file-based provider:

```csharp
var directoryInfo = new DirectoryInfo("./checkpoints");
var fileStore = new FileSystemJsonCheckpointStore(directoryInfo);
var checkpointManager = CheckpointManager.CreateJson(fileStore, new JsonSerializerOptions());
```

### A custom store

To keep workflow state in a database, implement `ICheckpointStore<T>`:

```csharp
using Microsoft.Agents.AI.Workflows;
using Microsoft.Agents.AI.Workflows.Checkpointing;
using System.Text.Json;

public class DbCheckpointStore : ICheckpointStore<JsonElement>
{
    public async ValueTask<CheckpointInfo> CreateCheckpointAsync(
        string sessionId,
        JsonElement value,
        CheckpointInfo parent)
    {
        var checkpointId = Guid.NewGuid().ToString();
        // Save 'value' JSON element linked to checkpointId in DB

        return new CheckpointInfo(sessionId, checkpointId);
    }

    public async ValueTask<JsonElement> RetrieveCheckpointAsync(
        string sessionId,
        CheckpointInfo key)
    {
        // Load JsonElement by key.CheckpointId from DB
    }

    public async ValueTask<IEnumerable<CheckpointInfo>> RetrieveIndexAsync(
        string sessionId,
        CheckpointInfo withParent)
    {
        // Query child checkpoints for parent
    }
}
```

## 🔎 Resolving the latest checkpoint

`CheckpointManager` finds a session's most recent checkpoint directly, so the host does not have to track the last `CheckpointInfo` it saw:

```csharp
CheckpointManager manager = CheckpointManager.CreateJson(store, new JsonSerializerOptions());

CheckpointInfo? latest = await manager.GetLatestCheckpointAsync(sessionId, cancellationToken);
if (latest is null)
{
    // This session has never checkpointed -- start a new run rather than resuming.
}
```

> [!IMPORTANT]
> **`GetLatestCheckpointAsync` returns a nullable `CheckpointInfo?`.** A session that has never checkpointed yields `null`. Declare the result nullable and branch on it; `CheckpointInfo latest = await …` raises **CS8600** and sets up a null dereference at resume. The surface dump shows a non-nullable return because reflection carries no nullable-reference annotations, so this is a compile-test fact in every version from v1.15 onward.

<!-- shared:v115-checkpoint-adoption-traps -->
| Trap | Reality |
| --- | --- |
| Hand-tracking the newest `CheckpointInfo` on v1.15+ | `CheckpointManager.GetLatestCheckpointAsync(sessionId)` resolves it; the token is optional. It resolves *identity*, not compatibility — still validate before resuming. |
| Assigning the result to a non-nullable `CheckpointInfo` | The return is **`CheckpointInfo?`** — a session with no checkpoints yields `null`. `CheckpointInfo latest = await …` raises CS8600 and sets up a null dereference on resume. The surface dump cannot show this; only a compile test does. |
<!-- /shared:v115-checkpoint-adoption-traps -->

## 🧭 The durable-state contract

1. Decide what belongs in scoped workflow state versus an external store. Checkpoints are for resuming a run, not for being your application database.
2. Persist checkpoints at meaningful recovery boundaries — and decide, per hosted workflow agent, whether they live in the session blob or in a `CheckpointManager` you own ([Workflow Hosting](workflow-hosting.md)).
3. Save the workflow/package version and application schema version beside the checkpoint identity.
4. On resume, resolve the entry point and validate compatibility **before** positioning a session on a checkpoint.
5. Test process restart, duplicate resume, corrupt state, cancellation, and partial side effects.

The invocable-function bypass (see [Agent Middleware and Routing](agent-middleware.md)) **stores function calls in the agent session** between requests. A session serialized between those two requests carries pending calls that will execute on the next turn — treat that state as part of the session's schema, and expect a resume across a package upgrade to be the moment it matters.

Treat custom Magentic prompts as deployment configuration: pin the text with the deployment, version it alongside the workflow, and treat a prompt change like any other compatibility question at resume time.

## ✅ Review checklist

- State scope and ownership are documented, and no executor reads a key it queued in the same superstep.
- Checkpoint payloads have a schema/version strategy, stored beside the checkpoint identity.
- A session with no checkpoints yet is handled explicitly — the `null` return of `GetLatestCheckpointAsync` is branched on, not assumed away.
- Resume is idempotent at every external side-effect boundary.
- Sessions that may carry bypassed (stored) function calls are versioned like any other persisted state.
- Prompt/configuration drift between the checkpointing process and the resuming process is accounted for.
- Agent-mode access uses the asynchronous contract introduced in v1.14.

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The scoped-state and checkpointing surfaces are byte-identical from v1.15 through v1.20 by mechanical diff. **Provenance:** the scoped-state and checkpoint-store samples were compile-tested against pinned **1.12.0** (surface-verified 1.13.0); `GetLatestCheckpointAsync` and its optional token against **1.15.0**, with the **nullable** `CheckpointInfo?` return (CS8600) re-confirmed by compile test on **1.17.0**. Nullability, like optionality, is absent from a reflection dump, so those two are asserted from those compiles and not from the 1.19.0 surface. Consolidated into this folder on 2026-09-01 from the v1.13 and v1.15 guides, and split from [Workflow Hosting](workflow-hosting.md) to keep each page inside the per-page budget; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
