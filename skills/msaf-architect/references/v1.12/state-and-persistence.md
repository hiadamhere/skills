# 💾 Workflow State & Persistence (v1.12)

Managing session values, variables, and checkpoint snapshots in MAF v1.12.x relies on scoped state and the dedicated checkpointing namespace.

---

## 🔄 Scoped State Model

MAF v1.12.x separates state into scopes to isolate executor contexts and prevent key collisions. State is access-controlled via `IWorkflowContext` passed to `HandleAsync`.

---

## ⚙️ Using `IWorkflowContext`

The `IWorkflowContext` provides thread-safe, scoped state operations:

### 1. Reading Scoped State
```csharp
public override async ValueTask<ProcessResult> HandleAsync(
    string message, 
    IWorkflowContext context, 
    CancellationToken ct)
{
    // 1. Read state from a specific executor scope
    var config = await context.ReadStateAsync<RunConfig>("run-config", "scope-name", ct);
    
    // 2. Read or initialize if not found (atomic)
    var tracker = await context.ReadOrInitStateAsync<ProgressTracker>(
        "progress", 
        () => new ProgressTracker(), 
        "scope-name", 
        ct);

    return new ProcessResult(tracker.Step);
}
```

### 2. Queuing State Updates
To maintain superstep determinism, state updates are queued during executor execution and committed atomically at the synchronization barrier (superstep completion).

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

---

## 🗄️ Checkpoint Store & Persistence

MAF v1.12.x features a formal checkpointing framework (`Microsoft.Agents.AI.Workflows.Checkpointing`).

### 1. Checkpoint Manager
Checkpoints are coordinated using the `CheckpointManager` class.
* **In-Memory Store:** `CheckpointManager.CreateInMemory()` (ideal for testing).
* **JSON Store:** `CheckpointManager.CreateJson(ICheckpointStore<JsonElement> store, JsonSerializerOptions options)`.
* **Default:** `CheckpointManager.Default`.

### 2. Creating custom checkpoint stores
To store workflow states in a persistent database, implement `ICheckpointStore<T>`:

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

### 3. File System Store
MAF ships with a built-in file-based checkpoint provider:
```csharp
var directoryInfo = new DirectoryInfo("./checkpoints");
var fileStore = new FileSystemJsonCheckpointStore(directoryInfo);
var checkpointManager = CheckpointManager.CreateJson(fileStore, new JsonSerializerOptions());
```

<!-- shared:workflow-hosting -->
## 🧭 Hosting a workflow as an agent

`WorkflowHostingExtensions.AsAIAgent` (present since v1.10; every parameter optional) turns a `Workflow` into an `AIAgent`, so a host that speaks agents — sessions, `RunAsync`, serialization — can run a graph without knowing it is one. Two facts hold in every verified version:

- **The workflow must speak the chat protocol.** `AsAIAgent` accepts any `Workflow`, but the first `RunAsync` throws an **InvalidOperationException** (*"Workflow does not support ChatProtocol: At least List<ChatMessage> and TurnToken must be supported as input"*) unless the start executor accepts `List<ChatMessage>` and `TurnToken`. A bare `Executor<string, string>` graph fails here; a `BuildSequential` workflow qualifies.
- **Give it an explicit `id`.** Without one the agent gets a fresh identifier per call, and `Name` / `Description` are empty.

Executed against pinned 1.14.0, 1.17.0 and 1.19.0; the signature is identical in every dump from 1.10.0. The v1.19 controls for where a hosted agent's checkpoints live are in [the v1.19 state guide](../v1.19/state-and-persistence.md).
<!-- /shared:workflow-hosting -->

---
*Verified against MAF v1.12.0 DLL surface (2026-07-03). Workflow-hosting block added 2026-08-27: `AsAIAgent` executed against pinned 1.14.0, 1.17.0 and 1.19.0.*
