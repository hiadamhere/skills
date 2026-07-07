# 🚀 Production Readiness, Telemetry & Testing (v1.11)

DI, observability, resilience, and testing for MAF v1.11.x. The v1.11 Workflows API is identical to v1.12 here (DLL-verified against the v1.11.0 packages).

---

## 🔌 Dependency Injection (DI)

Executors are plain classes — register them in `IServiceCollection` and consume services via constructor injection. Raw executor instances are accepted by the builder (implicit `Executor` → `ExecutorBinding` conversion); use `ExecutorBindingExtensions.BindExecutor<T>(factory)` when you need per-session DI resolution instead of singletons captured at build time.

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Agents.AI.Workflows;

public static class WorkflowServiceExtensions
{
    public static IServiceCollection AddAgentWorkflows(this IServiceCollection services)
    {
        // 1. Register downstream services
        services.AddHttpClient<IApiService, ApiService>();

        // 2. Register executors (transient prevents state leaks between runs)
        services.AddTransient<InputReader>();
        services.AddTransient<TextAnalyzer>();
        services.AddTransient<OutputFormatter>();

        // 3. Register the workflow definition
        services.AddSingleton<Workflow>(sp =>
        {
            var reader    = sp.GetRequiredService<InputReader>();
            var analyzer  = sp.GetRequiredService<TextAnalyzer>();
            var formatter = sp.GetRequiredService<OutputFormatter>();

            return new WorkflowBuilder(reader)
                .AddEdge(reader, analyzer)
                .AddEdge(analyzer, formatter)
                .WithOutputFrom(formatter)
                .Build();
        });

        return services;
    }
}
```

---

## 📊 Observability & OpenTelemetry

MAF emits OpenTelemetry-compliant traces for the run, each superstep, and each executor execution, propagating Activity context so LLM client calls link back to the graph.

```csharp
using OpenTelemetry.Trace;

var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("Microsoft.Agents.AI.Workflows") // Register MAF source
    .AddOtlpExporter(opt => opt.Endpoint = new Uri("http://localhost:4317"))
    .Build();
```

---

## 🛡️ Exception Handling & Resilience

If an executor throws during `HandleAsync`, the superstep is aborted and the failure surfaces on the event stream as `ExecutorFailedEvent` / `WorkflowErrorEvent` (there is **no** `RunStatus.Failed` value — the status enum is `NotStarted, Idle, PendingRequests, Ended, Running`). Watch the event stream to detect and report failures.

For transient faults (429s, sockets), wrap executor internals in a retry policy:

```csharp
using Polly;
using Polly.Retry;

public sealed class RobustAnalyzer : Executor<string, AnalysisResult>
{
    private readonly AsyncRetryPolicy _retryPolicy;

    public RobustAnalyzer() : base("robust-analyzer")
    {
        _retryPolicy = Policy
            .Handle<HttpRequestException>()
            .Or<ApiRateLimitException>()
            .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)));
    }

    public override async ValueTask<AnalysisResult> HandleAsync(
        string input,
        IWorkflowContext context,
        CancellationToken ct)
    {
        return await _retryPolicy.ExecuteAsync(async () =>
        {
            var result = await CallLLMServiceAsync(input, ct);
            return new AnalysisResult(result);
        });
    }
}
```

---

## 🧪 Testing Workflows

### 1. Unit Testing Executors
Executors are testable in isolation with a mocked `IWorkflowContext`:

```csharp
using Xunit;
using Moq;

public class TextAnalyzerTests
{
    [Fact]
    public async Task HandleAsync_ValidInput_ReturnsExpectedWordCount()
    {
        var mockContext = new Mock<IWorkflowContext>();
        var executor = new TextAnalyzer();

        var result = await executor.HandleAsync("Hello world", mockContext.Object, CancellationToken.None);

        Assert.Equal(2, result.WordCount);
    }
}
```

### 2. Integration Testing Graphs (In-Memory)
Assert on `RunStatus` via `GetStatusAsync` and on `WorkflowOutputEvent` entries from `run.NewEvents`. (`Run` has no `IsCompleted` or `Events` members, and `WorkflowOutputEvent` carries its payload via `Is<T>()` / `As<T>()`, not a `Data` property.)

```csharp
[Fact]
public async Task Integration_FullWorkflowRun_Succeeds()
{
    // Arrange
    var workflow = new WorkflowBuilder(new InputReader())
        .AddEdge(reader, analyzer)
        .AddEdge(analyzer, formatter)
        .WithOutputFrom(formatter)
        .Build();

    // Act
    Run run = await InProcessExecution.RunAsync(workflow, "Run integration test input");
    RunStatus status = await run.GetStatusAsync(CancellationToken.None);

    // Assert
    Assert.Equal(RunStatus.Ended, status);

    var outputEvent = run.NewEvents.OfType<WorkflowOutputEvent>().FirstOrDefault();
    Assert.NotNull(outputEvent);
    Assert.True(outputEvent.Is<FormatResult>());
    var formatResult = outputEvent.As<FormatResult>();
    Assert.Contains("PROCESSED", formatResult.Text);
}
```

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03).*
