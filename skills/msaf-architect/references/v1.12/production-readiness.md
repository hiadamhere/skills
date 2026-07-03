# 🚀 Production Readiness, Telemetry & Testing (v1.12)

Deploying MAF v1.12.x to production involves configuring scoped Dependency Injection, setting up streaming runners, and updating test assertions to match the new `Run` class models.

---

## 🔌 Dependency Injection (DI)

Because v1.12.x uses `ExecutorBinding`, DI registration typically binds executors to factory-based routes.

### Registration Pattern
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

---

## 📊 Streaming Execution (`StreamingRun`)

MAF v1.12.x supports real-time streaming of events (like token-by-token LLM output or superstep progress events) via `StreamingRun`.

```csharp
using Microsoft.Agents.AI.Workflows;

var sessionId = Guid.NewGuid().ToString();
StreamingRun run = await InProcessExecution.RunStreamingAsync(workflow, "My message", sessionId, ct);

await foreach (WorkflowEvent evt in run.WatchStreamAsync(ct))
{
    switch (evt)
    {
        case AgentResponseUpdateEvent update:
            // Print chunk to UI
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

---

## 📊 OpenTelemetry Instrumentation

Enable tracing using the standard workflow activity source name:

```csharp
using OpenTelemetry.Trace;

var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("Microsoft.Agents.AI.Workflows")
    .AddOtlpExporter()
    .Build();
```

---

## 🧪 Testing Workflows (v1.12)

Unit tests assert directly on `HandleAsync` values. Integration tests use `InProcessExecution` and assert on the `RunStatus` and emitted `WorkflowOutputEvent` structures.

### 1. Unit Testing Custom Executors
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

        var result = await executor.HandleAsync("Hello MAF 1.12", mockContext.Object, CancellationToken.None);

        Assert.Equal(3, result.Count);
    }
}
```

### 2. Integration Testing Graphs
```csharp
[Fact]
public async Task Integration_WorkflowCompletesSuccessfully()
{
    // Arrange
    var workflow = GetTestWorkflow();
    var sessionId = Guid.NewGuid().ToString();

    // Act
    Run run = await InProcessExecution.RunAsync(workflow, "Test Input", sessionId, CancellationToken.None);
    RunStatus status = await run.GetStatusAsync(CancellationToken.None);

    // Assert
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

---
*Verified against MAF v1.12.0 DLL surface (2026-07-03).*
