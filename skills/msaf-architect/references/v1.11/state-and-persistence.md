# 💾 Workflow State & Persistence (v1.11)

Session values, scoped state, and checkpoint persistence in MAF v1.11.x. The v1.11 Workflows API is identical to v1.12 here (DLL-verified against the v1.11.0 packages).

---

## 🔄 State Models

1. **Edge State (payloads):** state carried explicitly as typed messages between executors — preferred for pipeline inputs/outputs.
2. **Context State (shared, scoped):** values stored via `IWorkflowContext`, isolated under a `scopeName` to prevent key collisions between executors and concurrent runs.

---

## ⚙️ Using `IWorkflowContext`

### 1. Reading Scoped State
```csharp
public override async ValueTask<ProcessResult> HandleAsync(
    string message,
    IWorkflowContext context,
    CancellationToken ct)
{
    // Read from a specific scope
    var config = await context.ReadStateAsync<RunConfig>("run-config", "scope-name", ct);

    // Read or initialize atomically if absent
    var tracker = await context.ReadOrInitStateAsync<ProgressTracker>(
        "progress",
        () => new ProgressTracker(),
        "scope-name",
        ct);

    return new ProcessResult(tracker.Step);
}
```
Overloads without `scopeName` use the default scope.

### 2. Queuing State Updates
Updates are **value-based** (there is no updater-lambda overload): read, compute, then queue. Queued updates commit atomically at the superstep synchronization barrier, keeping concurrent executors deterministic.

```csharp
public override async ValueTask<OutputMessage> HandleAsync(
    InputMessage message,
    IWorkflowContext context,
    CancellationToken ct)
{
    var progress = await context.ReadOrInitStateAsync<ProgressTracker>(
        "progress", () => new ProgressTracker(), "scope-name", ct);

    var next = progress with { StepsCompleted = progress.StepsCompleted + 1 };
    await context.QueueStateUpdateAsync("progress", next, "scope-name", ct);

    // Clear an entire scope when a phase completes
    await context.QueueClearScopeAsync("scope-name", ct);

    return new OutputMessage("Step recorded.");
}
```

---

## 🗄️ Checkpoint Store & Persistence

For long-running workflows (especially HITL pauses), persist snapshots with the checkpointing framework (`Microsoft.Agents.AI.Workflows.Checkpointing`) — available in v1.11.

> [!WARNING]
> There is **no `IWorkflowStateStore` / `WorkflowState` abstraction and no `Microsoft.Agents.AI.Workflows.State` namespace** in any MAF version — those appear in some stale tutorials but were never shipped. Custom persistence is implemented through `ICheckpointStore<T>`.

### 1. Checkpoint Manager
* **In-memory (testing):** `CheckpointManager.CreateInMemory()`
* **JSON-backed:** `CheckpointManager.CreateJson(ICheckpointStore<JsonElement> store, JsonSerializerOptions options)`
* **Default:** `CheckpointManager.Default`

### 2. Custom Checkpoint Stores
```csharp
using Microsoft.Agents.AI.Workflows;               // CheckpointManager, CheckpointInfo
using Microsoft.Agents.AI.Workflows.Checkpointing; // ICheckpointStore<T>
using System.Text.Json;

public class DbCheckpointStore : ICheckpointStore<JsonElement>
{
    public async ValueTask<CheckpointInfo> CreateCheckpointAsync(
        string sessionId, JsonElement value, CheckpointInfo parent)
    {
        var checkpointId = Guid.NewGuid().ToString();
        // Save 'value' linked to checkpointId in your database
        return new CheckpointInfo(sessionId, checkpointId);
    }

    public async ValueTask<JsonElement> RetrieveCheckpointAsync(
        string sessionId, CheckpointInfo key)
    {
        // Load by key.CheckpointId
    }

    public async ValueTask<IEnumerable<CheckpointInfo>> RetrieveIndexAsync(
        string sessionId, CheckpointInfo withParent)
    {
        // Query child checkpoints of 'withParent'
    }
}
```

### 3. File System Store & Resuming
```csharp
var fileStore  = new FileSystemJsonCheckpointStore(new DirectoryInfo("./checkpoints"));
var manager    = CheckpointManager.CreateJson(fileStore, new JsonSerializerOptions());

// Run with checkpointing
Run run = await InProcessExecution.RunAsync(workflow, input, manager, sessionId, ct);

// After a restart, resume from a saved checkpoint
Run resumed = await InProcessExecution.ResumeAsync(workflow, fromCheckpoint, manager, ct);
```
A checkpoint captures the scoped state, pending edge messages, and execution pointers at a superstep boundary; a crashed host restarts from the last completed superstep.

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03).*
