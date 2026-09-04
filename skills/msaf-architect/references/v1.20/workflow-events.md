# 📡 Workflow Events (v1.20)

Streaming a workflow hands you a sequence of `WorkflowEvent`s. There are **21 event types** in a shallow hierarchy, and which one you get tells you what happened: an executor started, a superstep closed, a subworkflow warned, the run wants human input. Observability, progress reporting, and the human-in-the-loop pause all read from this one stream.

The event set is **identical across v1.11–v1.20** by mechanical surface diff — 21 types, unchanged.

## 🌊 Reading the Stream

```csharp
using Microsoft.Agents.AI.Workflows;

StreamingRun run = await InProcessExecution.RunStreamingAsync(workflow, input);

await foreach (WorkflowEvent evt in run.WatchStreamAsync())
{
    switch (evt)
    {
        case ExecutorInvokedEvent invoked:   Console.WriteLine($"-> {invoked.ExecutorId}"); break;
        case ExecutorCompletedEvent done:    Console.WriteLine($"<- {done.ExecutorId}");    break;
        case ExecutorFailedEvent failed:     Console.WriteLine(failed.Data);              break;
        case WorkflowOutputEvent output:     Console.WriteLine(output.SourceId);          break;   // keep last
    }
}
```

`RunStreamingAsync`'s `checkpointManager` and `sessionId` are **optional** — two arguments is the whole call. `WatchStreamAsync()` takes none.

> [!WARNING]
> **`InProcessExecution.StreamAsync` does not exist** (CS0117). The method is `RunStreamingAsync`, paired with `RunAsync` for the non-streaming form. There is also a `RunToCompletionAsync(handle, eventCallback, …)` helper that drains a `StreamingRun` for you and lets the callback return an `ExternalResponse` — the shape to reach for when the only reason you are watching is to answer requests.

## 🧬 The Hierarchy

Everything derives from `WorkflowEvent`, which carries a single `object Data` and overrides `ToString()`.

| Branch | Types | Carries |
|---|---|---|
| **Lifecycle** | `WorkflowStartedEvent` | the input message, as `Data` |
| **Supersteps** | `SuperStepEvent` → `SuperStepStartedEvent`, `SuperStepCompletedEvent` | `StepNumber`, plus `StartInfo` / `CompletionInfo` |
| **Executors** | `ExecutorEvent` → `ExecutorInvokedEvent`, `ExecutorCompletedEvent`, `ExecutorFailedEvent` | `ExecutorId` |
| **Output** | `WorkflowOutputEvent` → `AgentResponseEvent`, `AgentResponseUpdateEvent` | `ExecutorId`, `SourceId`, `Tags` |
| **Trouble** | `WorkflowErrorEvent` → `SubworkflowErrorEvent`; `WorkflowWarningEvent` → `SubworkflowWarningEvent` | `Exception` / message |
| **HITL** | `RequestInfoEvent` | the `ExternalRequest` |
| **Magentic** | `MagenticOrchestratorEvent` → `MagenticPlanCreatedEvent`, `MagenticReplannedEvent`, `MagenticProgressLedgerUpdatedEvent` | the ledger |

> [!WARNING]
> **Three things about this hierarchy will bite you.**
>
> 1. **`WorkflowOutputEvent` must be the LAST case in a `switch`.** `AgentResponseEvent` and `AgentResponseUpdateEvent` derive from it, so a `case WorkflowOutputEvent` placed above them swallows both — and it compiles, because it is a legal pattern order. You get "no agent responses" and nothing to explain it.
> 2. **The Magentic events are in a different namespace.** `MagenticPlanCreatedEvent`, `MagenticReplannedEvent` and `MagenticProgressLedgerUpdatedEvent` live in `Microsoft.Agents.AI.Workflows.Specialized.Magentic`, not `Microsoft.Agents.AI.Workflows`. Without that second `using` they are simply **CS0246 — not found**, which reads as "this version doesn't have them" rather than "you're missing an import".
> 3. **The failure payload is spelled two different ways.** `ExecutorFailedEvent` exposes its exception as **`Data`** (shadowing the base `object Data` with an `Exception`); `WorkflowErrorEvent` exposes its as **`Exception`**. Reaching for `.Exception` on the executor event, or `.Data` on the error event and expecting an exception, is the natural mistake in both directions.

## 🎯 Typed Output

`WorkflowOutputEvent` is the only branch with a real API on it, because output is the branch you actually inspect:

```csharp
if (output.IsIntermediate()) { return; }             // extension method

if (output.Is<string>(out string? summary))
{
    Console.WriteLine(summary);
}

if (output.IsType(typeof(int)))
{
    int value = output.As<int>();
}

bool tagged = output.HasTag(someTag);                // OutputTag is a struct
```

`Is<T>()` has both a plain and an `out`-parameter overload; `As<T>()` and `AsType(Type)` are the casting pair. `Tags` is an `IEnumerable<OutputTag>`, and every `WorkflowOutputEvent` constructor takes tags as either a single `OutputTag` or an enumerable. `IsIntermediate()` is an **extension** on `WorkflowOutputEventExtensions`, not an instance member — it needs the namespace in scope.

## 🪜 Superstep Detail

The two superstep events carry the richest diagnostic payload in the framework, and it is the fastest way to see why a Pregel/BSP workflow is slower than expected:

```csharp
case SuperStepStartedEvent start:
    Console.WriteLine($"step {start.StepNumber}: {string.Join(",", start.StartInfo.SendingExecutors)}" +
        (start.StartInfo.HasExternalMessages ? " (+external)" : ""));
    break;

case SuperStepCompletedEvent done:
    SuperStepCompletionInfo info = done.CompletionInfo;
    Console.WriteLine($"activated={info.ActivatedExecutors.Count} instantiated={info.InstantiatedExecutors.Count} " +
        $"stateUpdated={info.StateUpdated} pendingMessages={info.HasPendingMessages} " +
        $"pendingRequests={info.HasPendingRequests} checkpoint={info.Checkpoint}");
    break;
```

`HasPendingRequests` is the signal that the run is waiting on a human; `Checkpoint` is a `CheckpointInfo` you can carry to a later resume. See [Human-in-the-Loop and Routing](hitl-and-routing.md) and [State and Persistence](state-and-persistence.md).

## ✍️ Emitting Your Own

`WorkflowEvent` is **not sealed**, and `IWorkflowContext.AddEventAsync` takes the base type — so an executor can put its own progress on the same stream rather than inventing a side channel:

```csharp
sealed class ProgressEvent : WorkflowEvent
{
    public ProgressEvent(int percent) : base(percent) { }
}

// inside an executor
await context.AddEventAsync(new ProgressEvent(50));
```

`ExecutorEvent`, `SuperStepEvent`, `WorkflowOutputEvent`, `WorkflowErrorEvent` and `WorkflowWarningEvent` are likewise open for derivation; the leaf types are `sealed`.

## 🧭 Which Event Answers Which Question

| You want to know… | Watch for |
|---|---|
| Did the run start, and with what | `WorkflowStartedEvent` |
| Which executors ran this step, and did state change | `SuperStepCompletedEvent` |
| Which executor is running right now | `ExecutorInvokedEvent` |
| Why an executor threw | `ExecutorFailedEvent` (`.Data`) |
| The workflow's actual result | `WorkflowOutputEvent` (`.Is<T>()` / `.As<T>()`) |
| Streaming agent text as it arrives | `AgentResponseUpdateEvent` (`.AsResponse()` to fold) |
| That the run needs a human | `RequestInfoEvent` |
| Whether a nested workflow is in trouble | `SubworkflowErrorEvent` / `SubworkflowWarningEvent` |
| What a Magentic manager planned | `MagenticPlanCreatedEvent`, `MagenticReplannedEvent` |

## 🧩 Observing a workflow hosted as an agent

A workflow hosted as an agent (`AsAIAgent`, see [Workflow Hosting](workflow-hosting.md)) is observed through the *agent* surface — `RunAsync` / `RunStreamingAsync` and agent response updates — not through `WatchStreamAsync`. The event taxonomy above is what you get when you run the `Workflow` directly.

For the run/resume mechanics see [State and Persistence](state-and-persistence.md) and [Workflow Hosting](workflow-hosting.md); for `RequestInfoEvent` and the pause-for-human path see [Human-in-the-Loop and Routing](hitl-and-routing.md).

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The 21-type event taxonomy is identical across v1.11–v1.20 by mechanical diff, so the 1.20.0 surface this page targets is unchanged. **Provenance:** the compile- and execution-test facts on this page (the `WorkflowOutputEvent` case-order trap, the Magentic namespace split, and the two spellings of the failure payload) come from a probe compiled against pinned 1.11.0, 1.14.0 and 1.17.0 and are carried here on surface byte-identity, not re-executed on 1.19.0 or 1.20.0. Consolidated into this folder on 2026-09-01 from the v1.11 guide; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
