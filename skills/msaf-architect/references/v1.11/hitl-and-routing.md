# 🔀 Workflow Routing & Human-in-the-Loop (HITL) (v1.11)

Routing, loops, and human-in-the-loop patterns for MAF v1.11.x. The v1.11 Workflows API is identical to v1.12 for everything on this page (DLL-verified); it is documented here against the v1.11.0 packages.

---

## 🔀 Conditional Routing & Switch Predicates

### 1. Adding Conditional Edges
Add multiple outgoing edges from a single executor with a typed predicate. Raw executor instances are accepted directly (an implicit `Executor` → `ExecutorBinding` conversion exists):

```csharp
var classifier = new ContentClassifier();
var supportHandler = new SupportTeamHandler();
var salesHandler = new SalesTeamHandler();

WorkflowBuilder builder = new(classifier);

// Route based on classification category
builder.AddEdge(classifier, supportHandler, (TicketMessage m) => m.Category == Category.Support);
builder.AddEdge(classifier, salesHandler,   (TicketMessage m) => m.Category == Category.Sales);
```

### 2. Safeguards for Routing
* **Exclusivity:** predicates from a single source should be mutually exclusive; if several evaluate to `true` in one superstep, the message fans out to every matching path.
* **Fallback (default) routing:** always define a fallback edge so unmatched messages cannot stall the run:
  ```csharp
  builder.AddEdge(classifier, generalHandler, (TicketMessage m) =>
      m.Category != Category.Support && m.Category != Category.Sales);
  ```
* For larger branch sets, prefer the switch API: `builder.AddSwitch(sourceBinding, sw => { sw.AddCase<T>(pred, targets); sw.WithDefault(targets); })`.

---

## 🔁 Cycles & Loops

Cycles (e.g. reviewer sends a document back to the writer) are fully supported.

> [!CAUTION]
> Unbounded loops can exhaust API budgets. Implement a **stop-rule / iteration-counter guard** on every cycle path.

### Loop Counter Guard Pattern
Track the count in scoped context state. Note: state updates are **value-based** — read, compute, then queue the new value (there is no updater-lambda overload):

```csharp
public sealed class RevisionEvaluator : Executor<RevisionInput, RevisionOutput>
{
    public RevisionEvaluator() : base("revision-evaluator") { }

    public override async ValueTask<RevisionOutput> HandleAsync(
        RevisionInput input,
        IWorkflowContext context,
        CancellationToken ct)
    {
        var loopCount = await context.ReadStateAsync<int>("revision-loop-count", ct);

        if (loopCount >= 5) // Stop-rule threshold
        {
            await context.QueueStateUpdateAsync("revision-loop-count", 0, ct);
            return new RevisionOutput(input.Document, approved: false, limitReached: true);
        }

        await context.QueueStateUpdateAsync("revision-loop-count", loopCount + 1, ct);
        var isApproved = Evaluate(input.Document);
        return new RevisionOutput(input.Document, isApproved, limitReached: false);
    }
}
```

---

## 👥 Human-in-the-Loop (HITL) with RequestPorts

HITL in v1.11 uses the declared `RequestPort` — the same model as v1.12.

> [!WARNING]
> `WorkflowSuspendedException` **does not exist in MAF v1.11** (or any other version). Do not use a suspend-by-exception pattern from older tutorials or model memory — it will not compile. There is also no `InProcessExecution.ResumeAsync(workflow, runId)`; resumption goes through the `Run` object or a checkpoint.

### 1. Declaring the Port
```csharp
// 1. Declare the port with typed request/response payloads
var approvalPort = RequestPort.Create<ApprovalRequest, ApprovalResponse>("admin-approval");

// 2. Bind it as an executor node
var approvalBinding = ExecutorBindingExtensions.BindAsExecutor(approvalPort, allowWrappedRequests: true);

// 3. Wire it between the requesting and consuming nodes
builder.AddEdge(initiator, approvalBinding);
builder.AddEdge(approvalBinding, finalizer);
```

### 2. Pausing & Resuming
When execution reaches the port, the run suspends and reports `RunStatus.PendingRequests`:

```csharp
Run run = await InProcessExecution.RunAsync(workflow, initialInput, sessionId, ct);

if (await run.GetStatusAsync(ct) == RunStatus.PendingRequests)
{
    // Deliver the human decision when it arrives (e.g. from your approval web UI):
    var response = ExternalRequest
        .Create(approvalPort, requestData, "req-id")
        .CreateResponse(new ApprovalResponse { Approved = true });

    await run.ResumeAsync(new[] { response }, ct);
}
```

For pauses that must survive a process restart, combine the port with checkpointing (`CheckpointManager` + `InProcessExecution.ResumeAsync(workflow, fromCheckpoint, checkpointManager, ct)`) — see [state-and-persistence.md](state-and-persistence.md).

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03).*
