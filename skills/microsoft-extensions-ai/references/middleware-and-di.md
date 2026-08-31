# 🧱 The Middleware Pipeline and Dependency Injection

An `IChatClient` is a decorator chain. `ChatClientBuilder` wraps a provider client in layers — function invocation, caching, telemetry, logging — and `Build()` returns the composed client. The same shape exists for embeddings via `EmbeddingGeneratorBuilder<TInput, TEmbedding>`.

---

## Building a pipeline

```csharp
using Microsoft.Extensions.AI;

IChatClient client = raw.AsBuilder()
    .UseDistributedCache(cache)              // outermost: serve repeats without calling the model
    .UseFunctionInvocation(loggerFactory)    // execute tool calls
    .UseOpenTelemetry(loggerFactory, sourceName: "MyApp")
    .UseLogging(loggerFactory)               // innermost: closest to the provider call
    .Build();
```

`AsBuilder()` is an extension on `IChatClient`; `new ChatClientBuilder(innerClient)` is equivalent.

> [!IMPORTANT]
> **Order is behavior, not style.** Each `Use…` wraps everything registered before it, so the first registration sits *outermost* and sees the request first. Put the cache outside function invocation and a cache hit skips the whole tool loop; put it inside and you cache individual provider round-trips instead. Decide which one you actually want.

### Available layers

| Method | Adds |
|---|---|
| `UseFunctionInvocation(ILoggerFactory, Action<FunctionInvokingChatClient>)` | Executes tool calls — see [tool calling](tool-calling.md) |
| `UseDistributedCache(IDistributedCache, Action<DistributedCachingChatClient>)` | Caches responses in an `IDistributedCache` |
| `UseLogging(ILoggerFactory, Action<LoggingChatClient>)` | Logs requests and responses |
| `UseOpenTelemetry(ILoggerFactory, string sourceName, Action<OpenTelemetryChatClient>)` | OpenTelemetry traces/metrics |
| `UseChatReducer(IChatReducer, Action<ReducingChatClient>)` | Trims conversation history before the provider call |
| `ConfigureOptions(Action<ChatOptions>)` | Fills in per-call defaults (model, temperature, instructions) on a *clone* of the caller's options |
| `Use(Func<IChatClient, IChatClient>)` | Your own decorator |

`UseLogging` and `UseOpenTelemetry` also exist on the embedding, image-generator, speech-to-text, text-to-speech, and realtime builders.

`UseChatReducer`, `ReducingChatClient` and the shipped reducers (`MessageCountingChatReducer`, `SummarizingChatReducer`) are `[Experimental("MEAI001")]` — a compile error until suppressed (both forms in [routing-and-failover.md](routing-and-failover.md)); every other layer in the table is stable. Routing and failover clients are *root* clients, not layers: there is no `UseRouting()` or `UseFailover()` — you construct one and build the pipeline on top of it.

## Registering with dependency injection

`AddChatClient` returns the same `ChatClientBuilder`, so the pipeline is expressed inline at registration:

```csharp
using Microsoft.Extensions.AI;
using Microsoft.Extensions.DependencyInjection;

services.AddChatClient(innerClient)
        .UseFunctionInvocation()
        .UseLogging();

// Several clients in one app — resolve with [FromKeyedServices("fast")]
services.AddKeyedChatClient("fast", innerClient)
        .UseFunctionInvocation();

services.AddEmbeddingGenerator(embeddingGenerator)
        .UseLogging();
```

Each `Add…` has an `IServiceProvider`-factory overload for when the inner client needs resolved dependencies, plus a `ServiceLifetime` parameter.

- Consume `IChatClient` from DI; do not resolve the provider client directly, or you bypass every layer above.
- Register once at composition root. Building a pipeline per request throws away caching and adds allocation on a hot path.

## Custom middleware

A layer is a `DelegatingChatClient`: it wraps an inner client, forwards everything by default, and you override what you need.

```csharp
using Microsoft.Extensions.AI;

sealed class RedactingChatClient(IChatClient innerClient) : DelegatingChatClient(innerClient)
{
    public override Task<ChatResponse> GetResponseAsync(IEnumerable<ChatMessage> messages, ChatOptions? options = null, CancellationToken cancellationToken = default)
        => base.GetResponseAsync(Redact(messages), options, cancellationToken);

    public override IAsyncEnumerable<ChatResponseUpdate> GetStreamingResponseAsync(IEnumerable<ChatMessage> messages, ChatOptions? options = null, CancellationToken cancellationToken = default)
        => base.GetStreamingResponseAsync(Redact(messages), options, cancellationToken);

    private static IEnumerable<ChatMessage> Redact(IEnumerable<ChatMessage> messages) => messages;   // your policy here
}

IChatClient client = raw.AsBuilder()
    .Use(inner => new RedactingChatClient(inner))
    .UseFunctionInvocation()
    .Build();
```

- **Override both methods.** The base forwards `GetStreamingResponseAsync` straight to the inner client, so a layer that only overrides `GetResponseAsync` is bypassed by every streaming call.
- `InnerClient` is `protected` — the wrapped client is yours to call from inside the layer and nobody else's (CS0122 from outside). `GetService` and `Dispose` forward to it by default (executed: metadata resolved through the layer, the inner client disposed with it).
- Delegate-based overloads of `Use` intercept a call without a class, for one-off redaction, prompt-shaping or metrics.

### Defaults for every call

```csharp
IChatClient client = raw.AsBuilder()
    .ConfigureOptions(options =>
    {
        options.ModelId ??= "gpt-4o-mini";   // ??= fills only what the caller left null
        options.Temperature ??= 0.2f;
    })
    .Build();
```

`ConfigureOptions` runs your callback on a **clone** of the caller's `ChatOptions` (or on a fresh instance when none was passed), so the caller's object is never mutated and a value the caller did set survives a `??=` (executed).

## Engineering guidance

- **Telemetry belongs in the pipeline, not in call sites.** One `UseOpenTelemetry` registration covers every call through that client.
- **Caching is a correctness decision.** Cache only where an identical request genuinely should produce a reusable answer; a cached response to a tool-using request can serve stale tool output.
- Keep the pipeline definition in one place. A second `AsBuilder()` chain elsewhere in the codebase is how two "identical" clients quietly diverge.
- The pipeline is the seam for provider portability — swapping the innermost client should not change any layer above it.

## ✅ Review checklist

- Pipeline order is deliberate, and the cache/function-invocation relationship is the one intended.
- `IChatClient` is consumed from DI, not the raw provider client.
- The pipeline is built once at startup, not per request.
- Telemetry and logging are registered as layers rather than scattered through call sites.
- Custom layers derive from `DelegatingChatClient` and override *both* `GetResponseAsync` and `GetStreamingResponseAsync`.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28). Every code fence on this page compiles against 10.9.0. Execution facts: a `DelegatingChatClient` subclass forwards `GetService` and `Dispose` to its inner client and can sit in a `.Use(...)` layer; `InnerClient` is protected (CS0122 from outside); `ConfigureOptions` runs on a clone, so the caller's `ChatOptions` is never mutated and `??=` preserves caller-set values. The `MEAI001` gate on the chat reducers was established by reflection sweep and compile error.*
