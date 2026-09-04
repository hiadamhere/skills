# 🚀 Production Readiness, Telemetry & Testing (v1.20)

Getting a MAF workflow into production is three jobs: wiring it through DI, observing the run honestly, and testing the graph rather than only its parts. The Workflows runtime, streaming, cancellation, and execution surfaces are **byte-identical to v1.18** by mechanical diff, and v1.20 changes nothing in the Workflows assembly at all; what v1.19 adds is a routed-agent dimension in telemetry and one startup assertion, and v1.20 adds one knob on the background-agents provider.

---

## 🔌 Dependency Injection

Executors bind to factory-based routes, so DI registration resolves them through the service provider:

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Agents.AI.Workflows;

public static class WorkflowServiceExtensions
{
    public static IServiceCollection AddAgentWorkflows(this IServiceCollection services)
    {
        // 1. Register executors as transient services
        services.AddTransient<TextAnalyzer>();
        services.AddTransient<Formatter>();

        // 2. Register the singleton workflow using bindings resolved from DI
        services.AddSingleton<Workflow>(sp =>
        {
            // Bind using factories that resolve from the service provider
            var analyzerBinding = ExecutorBindingExtensions.BindExecutor<TextAnalyzer>(
                (id, sessionId) => new ValueTask<TextAnalyzer>(sp.GetRequiredService<TextAnalyzer>()));

            var formatterBinding = ExecutorBindingExtensions.BindExecutor<Formatter>(
                (id, sessionId) => new ValueTask<Formatter>(sp.GetRequiredService<Formatter>()));

            return new WorkflowBuilder(analyzerBinding)
                .AddEdge(analyzerBinding, formatterBinding)
                .WithOutputFrom(formatterBinding)
                .Build();
        });

        return services;
    }
}
```

## 📊 Streaming execution

```csharp
using Microsoft.Agents.AI.Workflows;

var sessionId = Guid.NewGuid().ToString();
StreamingRun run = await InProcessExecution.RunStreamingAsync(workflow, "My message", sessionId, ct);

await foreach (WorkflowEvent evt in run.WatchStreamAsync(ct))
{
    switch (evt)
    {
        case AgentResponseUpdateEvent update:
            Console.Write(update.Update.Text);
            break;

        case SuperStepCompletedEvent step:
            Console.WriteLine($"Superstep {step.StepNumber} complete.");
            break;

        case ExecutorCompletedEvent exec:
            Console.WriteLine($"Node {exec.ExecutorId} finished.");
            break;
    }
}
```

### Choosing the stream's behavior at a pending request

Since v1.15 the pending-request behavior is an explicit argument rather than a default you inherit:

| Call | Behavior |
|---|---|
| `run.WatchStreamAsync(cancellationToken)` | The original form, unchanged. |
| `run.WatchStreamAsync(blockOnPendingRequest, cancellationToken)` | Explicitly controls whether the stream blocks when the run reaches a pending human request. |

- The `CancellationToken` is **optional** on the newer overload — `run.WatchStreamAsync(blockOnPendingRequest: true)` compiles.
- Pass `false` when the host must observe the pending request and return control (a web request handler, a queue worker, any process that cannot sit inside an `await foreach` while a human decides). The host then persists the run identity and resumes later — see [Human-in-the-Loop and Routing](hitl-and-routing.md).
- Pass `true` for a long-lived interactive host that intends to keep the stream open across the human turn.
- Choose it deliberately. Whether a stream parks or yields at a human request is a hosting decision, and it is expressible in the call.

## 📈 OpenTelemetry instrumentation

```csharp
using OpenTelemetry;          // Sdk lives here
using OpenTelemetry.Trace;

var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("Microsoft.Agents.AI.Workflows")
    .AddOtlpExporter()
    .Build();
```

`AddOtlpExporter` comes from the `OpenTelemetry.Exporter.OpenTelemetryProtocol` package, which MAF does not pull in for you; `Sdk` is `OpenTelemetry.Sdk`, so the first `using` is not optional. Compile-tested with `OpenTelemetry.Exporter.OpenTelemetryProtocol` 1.15.3, which matches the `OpenTelemetry.Api` version the 1.20.0 packages declare in their nuspec (compiled against pinned 1.20.0).

## 🛠️ Operational guidance

- Pin the same MAF version across the agent, abstractions, and workflows packages unless a verified compatibility matrix says otherwise.
- Treat run identity, session identity, and checkpoint identity as three separate things in logs and dashboards. Recovery questions are asked in terms of all three.
- Treat streamed events as the authoritative run lifecycle. Distinguish completion, cancellation, failure, pending human input, and incomplete output collection — collapsing them into "done" makes the pending-request state invisible in production.
- Propagate cancellation from the host edge through the run, the executors, the wrapped agent calls, mode changes, and message-injection operations.
- Keep tool approval decisions observable and auditable without logging secrets or full sensitive arguments.
- Record the package version, workflow identity, run identity, agent identity, executor name, superstep, duration, and terminal status in telemetry.
- Make retries idempotent at side-effect boundaries. A workflow retry must not silently duplicate an email, payment, deployment, or data mutation.
- **From v1.18:** emit a metric when `ToolApprovalAgent` hits its auto-approval cap. That event is the difference between a model that finished and a model that was stopped from looping on an auto-approved tool.
- **From v1.18:** every host that starts background agents releases the session (`ReleaseSessionAsync`) on conversation end or eviction; otherwise abandoned tasks keep spending model and tool calls. The default waits up to 30 seconds for cancelled tasks — budget for that in shutdown paths.
- **From v1.18:** treat `AllowConcurrentInvocation = true` as a load-test item, not a flag. Tools that were only ever exercised one at a time have not been exercised at all under this setting.
- **New in v1.19:** record the **active route** on every turn of an agent whose chat client routes per session. Cost, latency, and quality all vary by route; a dashboard that cannot split by it cannot explain either.
- **New in v1.19:** at startup, read `WorkflowAgentMetadata` from every hosted workflow agent and assert `UsesOwnCheckpointStorage` matches what the host believes. A `false` where you expected `true` means checkpoints are in the session blob, not in your store — and `WithCheckpointing` returns the agent *unchanged* when it is behind a wrapper, so this is the check that catches a silent no-op.
- **New in v1.19:** MAF 1.19.0 moves its `Microsoft.Extensions.AI` dependency to 10.9.0 (1.17 and 1.18 referenced 10.7.0). A project that also references `Microsoft.Extensions.AI` directly needs a version of at least 10.9.0 alongside the 1.19.0 packages. 1.20.0 keeps the 10.9.0 floor; its only dependency moves are `Microsoft.Extensions.VectorData.Abstractions` 10.7.0 → 10.8.2 and `Microsoft.Extensions.FileSystemGlobbing` 10.0.6 → 10.0.11 (package metadata).
- **New in v1.20:** if a host lets the parent agent wait on background tasks, set `BackgroundAgentsProviderOptions.WaitTimeout` deliberately — the default is **five minutes** of the wait tool blocking the run, and it is validated in the provider constructor, not where you set it. Details and the executed bounds are on the [Background Agents](background-agents.md) page.

## ⚗️ Experimental surface in production

The `MAAI001` inventory grows again. Gated in v1.19: the Magentic prompt customization from v1.16 (see [Human-in-the-Loop and Routing](hitl-and-routing.md)), the v1.18 invocable-function bypass and `BackgroundAgentsProvider`, and now `RoutePersistingRoutingChatClient` with its options, `WorkflowSessionCheckpointRecovery`, and `FeatureUsage`. v1.20 adds nothing to the list: its one new member, `WaitTimeout`, sits on `BackgroundAgentsProviderOptions`, which is gated at the type level (compile-tested unsuppressed against 1.20.0 — the diagnostic names the options type, not just the provider). **Not** gated: `WorkflowAgentMetadata`, `WithCheckpointing`, `AllowConcurrentInvocation`, `MaxAutoApprovalIterations`. Before shipping anything gated:

- Scope the suppression to the project that needs it, never the whole solution.
- Record which experimental APIs a release depends on, so the next MAF upgrade has a known blast radius.
- Keep a non-experimental fallback path if the run is business-critical; an evaluation-only API can change or disappear in a minor release.
- `FeatureUsage` is documented by the package as infrastructure not intended for applications. If a framework integration in your process appends its token to outbound User-Agent headers, know which destinations receive it.

## 🧪 Testing

Unit tests assert directly on `HandleAsync` values. Integration tests use `InProcessExecution` and assert on the `RunStatus` and emitted `WorkflowOutputEvent` structures.

```csharp
using Xunit;
using Moq;

public class TextAnalyzerTests
{
    [Fact]
    public async Task HandleAsync_CountsWordsCorrectly()
    {
        var mockContext = new Mock<IWorkflowContext>();
        var executor = new TextAnalyzer();

        var result = await executor.HandleAsync("Hello MAF", mockContext.Object, CancellationToken.None);

        Assert.Equal(2, result.Count);
    }
}
```

```csharp
[Fact]
public async Task Integration_WorkflowCompletesSuccessfully()
{
    var workflow = GetTestWorkflow();
    var sessionId = Guid.NewGuid().ToString();

    Run run = await InProcessExecution.RunAsync(workflow, "Test Input", sessionId, CancellationToken.None);
    RunStatus status = await run.GetStatusAsync(CancellationToken.None);

    Assert.Equal(RunStatus.Ended, status);

    var outputEvent = run.NewEvents
        .OfType<WorkflowOutputEvent>()
        .FirstOrDefault();

    Assert.NotNull(outputEvent);
    Assert.True(outputEvent.IsType(typeof(FormattedResult)));
    var data = outputEvent.As<FormattedResult>();
    Assert.Contains("TEST INPUT", data.Text);
}
```

### Test pyramid

1. Unit-test executor input/output and state changes without a network model where possible.
2. Build the real graph in integration tests so incompatible edges fail early.
3. Exercise streaming status, cancellation, checkpoint/resume, and human-request paths.
4. Compile-test every version-specific snippet against exact `1.20.0` packages.
5. Run a bounded live-model smoke test only after deterministic tests pass.

## ✅ Review checklist

- Cancellation is propagated from the host edge to every agent call.
- Pending-request runs are observable as their own state, not folded into failure or success.
- The stream's pending-request behavior is an explicit argument at every call site.
- The auto-approval cap and background-session release are observable in telemetry.
- The active route is recorded per turn for routed agents; `UsesOwnCheckpointStorage` is asserted at startup for hosted workflow agents.
- Experimental (`MAAI001`) usage is inventoried per release and isolated behind a project seam.

## ⬆️ Upgrading from v1.19 or v1.18

**From v1.19:** the entire 1.19.0 → 1.20.0 surface diff across all three assemblies is one added property, `BackgroundAgentsProviderOptions.WaitTimeout`; nothing was removed, renamed or re-gated, and v1.19 code compiles unchanged (the probe on the [Background Agents](background-agents.md) page fails against 1.19.0 only where it names the new member, CS1061). The `Microsoft.Extensions.AI` floor stays at 10.9.0.

**From v1.18:** nothing was removed or renamed — v1.19 is purely additive by mechanical surface diff across all three assemblies: `Microsoft.Agents.AI.Abstractions` gains `FeatureUsage`; `Microsoft.Agents.AI` gains `RoutePersistingRoutingChatClient` and `RoutePersistingRoutingChatClientOptions`; `Microsoft.Agents.AI.Workflows` gains `WorkflowAgentMetadata`, `WorkflowHostingExtensions.WithCheckpointing`, and `WorkflowSessionCheckpointRecovery`. v1.18 code compiles unchanged. The one thing that *does* move under existing code is the transitive `Microsoft.Extensions.AI` version.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). The six v1.19 members were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0; the `MAAI001` split and the dependency versions are compile-test and package-metadata facts a reflection dump cannot express. **Provenance of the carried-forward material:** the DI, streaming and testing samples were compile-tested on pinned **1.12.0/1.13.0**; the `WatchStreamAsync(blockOnPendingRequest, …)` overload and its optional token on **1.15.0**; the v1.18 operational items on **1.18.0**. The Workflows production surface is byte-identical from v1.13 through v1.20 by mechanical diff, which is what carries them here — they were not re-executed on 1.19.0 or 1.20.0. Consolidated into this folder on 2026-09-01 from the v1.13, v1.14, v1.15 and v1.18 guides; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated. Fixed in place on 2026-09-03: the OpenTelemetry sample lacked `using OpenTelemetry;` (`Sdk` is in that namespace, CS0103 without it) and never named the exporter package; both corrected, compile-tested in the catalog's private compile harness (`probe-visualizer-views`) against pinned 1.20.0 with `OpenTelemetry.Exporter.OpenTelemetryProtocol` 1.15.3.*
