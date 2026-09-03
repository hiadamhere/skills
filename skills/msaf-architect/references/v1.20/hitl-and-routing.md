# 🔀 Human-in-the-Loop and Routing (v1.20)

Typed-edge routing, `ExecutorBinding`, fan-out/fan-in, the `RequestPort` HITL model, and the Magentic manager are all here. The whole surface is **byte-identical from v1.16 through v1.20** by mechanical diff; the three members v1.19 adds to the Workflows assembly are hosting and checkpoint controls, documented in [Workflow Hosting](workflow-hosting.md).

> [!WARNING]
> **`WorkflowSuspendedException` is not part of the shipped API in any version.** A suspend-by-exception pattern found in stale tutorials and model memory will not compile. Human input is pending requests plus `Run.ResumeAsync`, always.

---

## 🔀 `WorkflowBuilder` and `ExecutorBinding`

For custom directed graphs, `WorkflowBuilder` takes `ExecutorBinding`s rather than raw `Executor` instances.

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

```csharp
var builder = new WorkflowBuilder(readerBinding);

// Unconditional edge
builder.AddEdge(readerBinding, analyzerBinding);

// Fan-out
builder.AddFanOutEdge(analyzerBinding, new[] { loggerBinding, dbWriterBinding });
```

### Conditional routing (`SwitchBuilder`)

```csharp
builder.AddSwitch(analyzerBinding, sw =>
{
    sw.AddCase<AnalysisResult>(res => res.IsSpam, new[] { spamFilterBinding });
    sw.WithDefault(new[] { outputFormatterBinding });
});
```

### Routing rules

- Validate every edge as a type contract. Insert a mapping executor when the producer and consumer message types differ.
- Use builder-native fan-out and fan-in so the runtime retains telemetry, ordering, and checkpoint semantics.
- Remember the bulk-synchronous execution barrier: a branch does not run indefinitely ahead of its siblings across supersteps.
- Keep sequential work in one executor when splitting it would add barriers without adding a useful routing, persistence, or ownership boundary.
- Treat conditional routing as a graph decision with explicit outcomes; avoid hiding graph topology in unmanaged tasks inside an executor.
- **Routing between chat clients is not graph routing.** `RoutePersistingRoutingChatClient` (see [Agent Middleware and Routing](agent-middleware.md)) chooses which model answers *one agent's* turn, per session; it does not move a message between executors. Use it for cost or capability tiers inside a participant, and edges for topology.

## 🏗️ Orchestration builders

> [!IMPORTANT]
> **The traps live in the dedicated guide.** This section shows the shapes; [Orchestration Patterns](orchestration-patterns.md) carries the three things a surface dump cannot tell you — `BuildConcurrent`'s aggregator reads as required but is optional, `GroupChatWorkflowBuilder` has no public constructor, and there are two handoff builder types that both work. Read it before writing any of these topologies.

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

## 👥 Human-in-the-loop and `RequestPort`

### Declaring a port

```csharp
// 1. Declare the port
var approvalPort = RequestPort.Create<ApprovalRequest, ApprovalResponse>("admin-approval");

// 2. Bind the port in your graph
var approvalBinding = ExecutorBindingExtensions.BindAsExecutor(approvalPort, allowWrappedRequests: true);

// 3. Add edges passing through the port
builder.AddEdge(initiatorBinding, approvalBinding);
builder.AddEdge(approvalBinding, finalizerBinding);
```

### Resuming

When the workflow reaches a `RequestPort`, the runtime suspends at the superstep boundary.

```csharp
Run run = await InProcessExecution.RunAsync(workflow, initialInput, sessionId, ct);

var status = await run.GetStatusAsync(ct);
if (status == RunStatus.PendingRequests)
{
    // The workflow is paused, waiting for input. When input arrives externally:
    var approvalResult = new ApprovalResponse { Approved = true };
    var response = ExternalRequest.Create(approvalPort, approvalResult, "req-id").CreateResponse(approvalResult);

    await run.ResumeAsync(new[] { response }, ct);
}
```

### The host's contract

1. Declare a `RequestPort` for the human decision.
2. Run the workflow; a pending request surfaces through `RunStatus.PendingRequests`.
3. Persist the request and run identity, then return control to the host.
4. The run continues through `Run.ResumeAsync` with that response.
5. Cancellation, expiry, duplicate responses, and unauthorized responders are handled as explicit host states.

Do not resume a run from display text alone — bind the response to the stored request and run identity.

**The streaming side is a separate decision.** `StreamingRun.WatchStreamAsync(blockOnPendingRequest, cancellationToken)` lets the host choose whether the event stream parks or yields at a pending request; see [Production Readiness](production-readiness.md). The request/response contract itself is unchanged by that choice.

**When the workflow is hosted as an agent** (`AsAIAgent`), an interrupted run is continued through the session's `WorkflowSessionCheckpointRecovery` service rather than through `Run.ResumeAsync` — the host resolves the checkpoint, validates it, then calls `TryPrepare`. That service is `MAAI001`-gated and does **not** validate the id it is given; see [Workflow Hosting](workflow-hosting.md) before relying on it.

## 🧲 Magentic manager and prompt customization

> [!WARNING]
> Magentic prompt customization raises **`MAAI001` as a compile error** until suppressed with `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. Four releases behind an experimental flag is not a promotion signal: treat `MagenticPromptOverrides`, `MagenticDefaultPrompts`, `WithPromptOverrides`, and `WithResponseLanguage` as subject to change, and keep them behind your own seam. The pre-existing builder API (`MagenticWorkflowBuilder`, `AddParticipants`, `WithMaxRounds`, `WithMaxStalls`, `RequirePlanSignoff`, `Build`) is **not** gated.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

Workflow workflow = new MagenticWorkflowBuilder(managerAgent)
    .AddParticipants(participants)
    .WithPromptOverrides(new MagenticPromptOverrides
    {
        ProgressLedgerPrompt = "…",
        FinalAnswerPrompt    = "…",
    })
    .WithResponseLanguage("French")
    .WithMaxRounds(10)
    .Build();
```

`MagenticPromptOverrides` exposes seven prompt slots, one per stage of the manager's reasoning:

| Property | Stage it replaces |
|---|---|
| `TaskLedgerFactsPrompt` | Initial fact gathering. |
| `TaskLedgerPlanPrompt` | Initial plan construction. |
| `TaskLedgerFullPrompt` | The combined task ledger handed to participants. |
| `TaskLedgerFactsUpdatePrompt` | Fact revision after a reset/replan. |
| `TaskLedgerPlanUpdatePrompt` | Plan revision after a reset/replan. |
| `ProgressLedgerPrompt` | Per-round progress evaluation (stall and completion detection). |
| `FinalAnswerPrompt` | Final answer synthesis. |

`MagenticDefaultPrompts` exposes the shipped default for each slot as a `static readonly string` under the same seven names — read one when you want to extend a default rather than replace it.

> [!IMPORTANT]
> The properties are **`init`-only**. Set them in an object initializer; assigning after construction (`overrides.ProgressLedgerPrompt = "…"`) does not compile. Any slot you leave unset keeps its shipped default, so a partial override is the normal case.

Both new builder methods take a nullable, optional argument (`WithPromptOverrides(MagenticPromptOverrides? = …)`, `WithResponseLanguage(string? = …)`), so passing `null` is a legal "use the defaults" call.

### Engineering guidance

- Override the narrowest slot that solves the problem. Replacing `TaskLedgerFullPrompt` because the final answer read badly discards planning behavior you did not intend to change.
- `ProgressLedgerPrompt` governs stall and completion detection. A weakened version here does not produce a worse answer — it produces a loop that does not terminate. Keep `WithMaxRounds` / `WithMaxStalls` bounds in place as the failure-safe.
- Prefer `WithResponseLanguage` over instructing the language inside a custom prompt; it is the supported seam and survives a prompt-default change.
- Never build an override string from untrusted input. These prompts drive the orchestrator, not a participant turn — injection here redirects the whole run.
- Pin the prompt text you ship and diff it against `MagenticDefaultPrompts` on every MAF upgrade. Defaults evolve; a frozen copy silently diverges.
- For Magentic specifically, `RequirePlanSignoff` is the plan-approval gate; do not reimplement it with a custom prompt that merely *asks* the model to wait for approval.

## ⚠️ Adoption traps

<!-- shared:v116-magentic-adoption-traps -->
| Trap | Reality |
| --- | --- |
| Writing `overrides.ProgressLedgerPrompt = "…"` after construction | `MagenticPromptOverrides` properties are **`init`-only**. Use an object initializer; the surface dump's `{ get; set; }` cannot distinguish `init` from `set`. |
| Expecting the v1.16 Magentic prompt API to just compile | It raises **`MAAI001` as an error**. Add `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. The pre-existing `MagenticWorkflowBuilder` methods are not gated. |
| Copying a default prompt once and freezing it | `MagenticDefaultPrompts` values are shipped defaults that evolve. Diff your overrides against them at every upgrade. |
<!-- /shared:v116-magentic-adoption-traps -->

## ✅ Review checklist

- All edges are type-compatible at `builder.Build()` time.
- Fan-in behavior is tested with late and failed branches.
- Every human request has authorization, expiry, idempotency, and audit rules.
- The stream's pending-request behavior is chosen deliberately, not inherited by accident.
- Resume tests use the real pending-request path rather than an invented exception flow.
- The host handles an approval request that surfaces after the v1.18 auto-approval cap.
- `MAAI001` suppression is scoped and reviewed, and experimental usage is isolated behind a project seam.
- Overridden prompts are version-pinned and diffed against `MagenticDefaultPrompts` at upgrade time.
- Round/stall bounds remain in place after any `ProgressLedgerPrompt` override.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). The routing and HITL surface is byte-identical from v1.16 through v1.20 by mechanical diff, and the `MAAI001` gate on the Magentic prompt surface — with the builder methods ungated — was **re-confirmed by compile test against the 1.19.0 packages**, because an attribute is not in the dump and byte-identity cannot carry it forward. **Provenance of the carried-forward material:** the binding, edge, switch and `RequestPort` samples were compile-tested on pinned **1.12.0** (surface-verified 1.13.0); the routing rules on **1.14.0**; the streaming/pending-request interaction on **1.15.0**; and the Magentic prompt surface — the `init`-only accessors, the optional/nullable parameters, and the `MagenticDefaultPrompts` members — on **1.16.0**, and are asserted from those compiles rather than from the 1.19.0 or 1.20.0 dumps: a surface dump renders neither `init` nor a parameter default, so byte-identity cannot carry them. Consolidated into this folder on 2026-09-01 from the v1.13, v1.14, v1.15 and v1.16 guides; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
