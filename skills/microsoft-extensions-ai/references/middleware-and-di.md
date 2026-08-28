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

```csharp
IChatClient client = raw.AsBuilder()
    .Use(inner => new MyPolicyChatClient(inner))
    .Build();
```

Delegate-based overloads of `Use` let you intercept `GetResponseAsync` (and streaming) without writing a class — useful for redaction, prompt-shaping, or request metrics.

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

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) (2026-08-28): every type on this page is byte-identical to 10.8.1 by mechanical diff of the dumps, and base types, parameter defaults, accessors and `[Experimental]` gating are unchanged by a reflection shape diff of both pins; the patterns were compile-tested against 10.8.1 on 2026-08-05. The `MEAI001` gate on this page's types was established on 10.9.0 by compile error and a reflection sweep of both assemblies for `[Experimental]`.*
