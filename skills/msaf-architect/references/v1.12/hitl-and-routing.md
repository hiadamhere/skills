# 🔀 Workflow Routing & Human-in-the-Loop (v1.12)

MAF v1.12.x introduces type-safe `ExecutorBinding` routing, declarative topology builders, and the native `RequestPort` HITL resumption model.

---

## 🏗️ Orchestration Builders

Instead of manually mapping edges for common patterns, MAF v1.12.x provides dedicated builders via `AgentWorkflowBuilder`:

```csharp
using Microsoft.Agents.AI.Workflows;

// 1. Sequential Agent Chain
Workflow seqWorkflow = AgentWorkflowBuilder
    .CreateSequentialBuilderWith(new[] { triageAgent, analyzerAgent })
    .WithChainOnlyAgentResponses(true)
    .Build();

// 2. Parallel Agent Execution with Aggregator
Workflow concurrentWorkflow = AgentWorkflowBuilder
    .CreateConcurrentBuilderWith(new[] { agentA, agentB })
    .WithAggregator(chatHistoryList => MergeHistories(chatHistoryList))
    .Build();

// 3. Agent Handoffs
Workflow handoffWorkflow = AgentWorkflowBuilder
    .CreateHandoffBuilderWith(triageAgent)
    .WithHandoffs(triageAgent, new[] { billingAgent, techAgent })
    .WithAutonomousMode(turnLimit: 10, "Continue...", new[] { billingAgent, techAgent }, null, null)
    .Build();
```

---

## 🔀 WorkflowBuilder & ExecutorBinding

For custom directed graphs, `WorkflowBuilder` uses `ExecutorBinding` instead of raw `Executor` instances.

### 1. Declaring Bindings
Use extension methods to wrap instances, factories, or subworkflows into bindings:
```csharp
// From instance
var readerBinding = ExecutorBindingExtensions.BindExecutor(new InputReader());

// From factory (supports dependency injection scopes)
var analyzerBinding = ExecutorBindingExtensions.BindExecutor<TextAnalyzer>((id, sessionId) => 
    new ValueTask<TextAnalyzer>(new TextAnalyzer()));

// From lambda
var loggerBinding = ExecutorBindingExtensions.BindAsExecutor<string>(
    msg => Console.WriteLine(msg), "logger", ExecutorOptions.Default, threadsafe: true);
```

### 2. Graph Edges
```csharp
var builder = new WorkflowBuilder(readerBinding);

// Unconditional edge
builder.AddEdge(readerBinding, analyzerBinding);

// Fan-out
builder.AddFanOutEdge(analyzerBinding, new[] { loggerBinding, dbWriterBinding });
```

### 3. Conditional Routing (`SwitchBuilder`)
Use the switch API to branch routes cleanly:
```csharp
builder.AddSwitch(analyzerBinding, sw => 
{
    sw.AddCase<AnalysisResult>(res => res.IsSpam, new[] { spamFilterBinding });
    sw.WithDefault(new[] { outputFormatterBinding });
});
```

---

## 👥 Human-in-the-Loop (HITL) & RequestPorts

HITL is modeled using a declared `RequestPort`. (Note: `WorkflowSuspendedException` never existed in any MAF version — a suspend-by-exception pattern found in stale tutorials and model memory will not compile.)

### 1. Declaring a RequestPort
Define the expected request and response payloads, and link it in the builder:
```csharp
// 1. Declare the port
var approvalPort = RequestPort.Create<ApprovalRequest, ApprovalResponse>("admin-approval");

// 2. Bind the port in your graph
var approvalBinding = ExecutorBindingExtensions.BindAsExecutor(approvalPort, allowWrappedRequests: true);

// 3. Add edges passing through the port
builder.AddEdge(initiatorBinding, approvalBinding);
builder.AddEdge(approvalBinding, finalizerBinding);
```

### 2. Resuming Execution
When the workflow hits a `RequestPort`, the execution runtime suspends automatically.

```csharp
// Run until suspend
Run run = await InProcessExecution.RunAsync(workflow, initialInput, sessionId, ct);

var status = await run.GetStatusAsync(ct);
if (status == RunStatus.PendingRequests)
{
    // The workflow is paused, waiting for input.
    // When input is received externally:
    var approvalResult = new ApprovalResponse { Approved = true };
    var response = ExternalRequest.Create(approvalPort, approvalResult, "req-id").CreateResponse(approvalResult);
    
    // Resume run passing the responses
    await run.ResumeAsync(new[] { response }, ct);
}
```
This preserves transaction safety and cleans up state synchronization at the superstep boundary.

---
*Verified against MAF v1.12.0 DLL surface (2026-07-03).*
