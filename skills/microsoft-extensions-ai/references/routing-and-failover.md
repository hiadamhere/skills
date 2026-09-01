# 🔀 Routing and Failover Between Chat Clients

Microsoft.Extensions.AI 10.9.0 adds a family of **root** clients that decide *which* `IChatClient` answers a request: `RoutingChatClient` (you decide, per request), `SemanticRoutingChatClient` (embedding similarity decides), and `FailoverChatClient` / `OrderedFailoverChatClient` (a failure decides). Each one *is* an `IChatClient`, so everything else in this skill — function invocation, caching, telemetry, DI — composes on top of it unchanged.

> [!IMPORTANT]
> **The whole family is `[Experimental("MEAI001")]`, and `MEAI001` is a compile *error*, not a warning.** `RoutingChatClient`, `RoutingContext`, `FailoverChatClient`, `FailoverChatClientAttempt`, `OrderedFailoverChatClient` and `SemanticRoutingChatClient` all fail to compile until the diagnostic is suppressed — either project-wide with `<NoWarn>$(NoWarn);MEAI001</NoWarn>` or per file with `#pragma warning disable MEAI001` (both verified). Treat the API as subject to change: keep the suppression in the project that owns the router, and keep the router behind your own seam.

> [!IMPORTANT]
> **There is no `UseRouting()` / `UseFailover()` / `UseSemanticRouting()` builder method** (CS1061). These are root clients you construct and then build *on*: `router.AsBuilder().UseFunctionInvocation().Build()` puts one function-invocation loop in front of whichever client the router picks; a pipeline built *inside* a candidate applies to that candidate only.

---

## Routing by your own rule

```csharp
using Microsoft.Extensions.AI;

IChatClient router = RoutingChatClient.Create((context, cancellationToken) =>
{
    // context.ChatOptions is NULL when the caller passed no options — never dereference it blindly.
    bool cheap = context.ChatOptions?.ModelId == "fast";
    return new ValueTask<IChatClient>(cheap ? fastClient : strongClient);
});
```

`RoutingContext` carries the request: `Messages` and `ChatOptions`, both read-only (CS0200). The selector runs once per request, for streaming and non-streaming alike; an exception it throws surfaces unchanged, and returning `null` is an `InvalidOperationException` ("SelectClientAsync returned null"), not a "no route" signal.

For a reusable policy, subclass instead of calling `Create` and implement the one abstract member — `protected abstract ValueTask<IChatClient> SelectClientAsync(RoutingContext, CancellationToken)`. Omit it and CS0534 names it; it is `protected`, so no reflection dump of public members will show it.

Two things a router deliberately does **not** do: `GetService` is answered by the router itself and never forwarded to a candidate (there is no request to route), and `Dispose()` on a `Create`d router leaves the candidates open — you own their lifetime.

## Semantic routing

```csharp
using Microsoft.Extensions.AI;

var profiles = new Dictionary<IChatClient, IReadOnlyList<string>>
{
    [codeClient]    = ["write code", "debug a program", "explain an exception"],
    [weatherClient] = ["weather forecast", "temperature", "rain"],
};

IChatClient router = new SemanticRoutingChatClient(
    embeddingGenerator,          // IEmbeddingGenerator<string, Embedding<float>>
    profiles,
    defaultClient: generalClient,
    scoreThreshold: 0.3f,        // default 0.3f
    topK: 1,                     // default 1
    scoreAggregation: SemanticRoutingChatClient.ScoreAggregation.Mean,   // default Mean
    leaveOpen: false);           // default false
```

The three-argument form compiles; the last four parameters carry the defaults shown. How it decides, established by execution against a deterministic embedding generator:

- **It embeds the text of the most recent *user* message** — not the last message of any role, and not the system prompt. A request whose last user message has no text (or has no user message at all) goes to `defaultClient` without calling the embedding generator.
- **Profile phrases are embedded lazily, once.** Nothing is embedded at construction; the first request embeds every phrase in a single batch and caches the result, then each request costs exactly one embedding call.
- **`topK` picks the K best-scoring phrases across *all* clients**, their scores are aggregated per client (`Mean` or `Sum`), and the best client wins if its **aggregate** clears `scoreThreshold`; otherwise `defaultClient` answers. With `topK` above 1, `Sum` favours a client that has several matching phrases and `Mean` does not.
- `leaveOpen: false` disposes the profile clients, the default client **and the embedding generator** when the router is disposed.
- An empty profile dictionary is an `ArgumentException`; a `null` default client is an `ArgumentNullException`.

## Failover

```csharp
using Microsoft.Extensions.AI;

IChatClient client = new OrderedFailoverChatClient([primary, secondary, tertiary])
{
    MaximumAttemptsPerRequest = 2,   // int?; null (the default) tries every client
};
```

`OrderedFailoverChatClient(IReadOnlyList<IChatClient> clients, bool leaveOpen = false)` tries the clients in order. Executed behaviour:

- **Any exception a client throws moves on to the next one** — including an `OperationCanceledException` the client raised on its own while your token is still live. Your own cancellation is honoured between attempts: a cancelled token stops the sequence with `OperationCanceledException` instead of trying the next client.
- **When every client fails, the *last* exception is rethrown as-is.** There is no aggregate; earlier failures are visible only through a policy's `OnRoutingUpdateAsync` (below).
- **`MaximumAttemptsPerRequest` caps attempts**, and the failure that hits the cap is rethrown with the remaining clients untried.
- `leaveOpen: false` (the default) disposes every client with the router; an empty list is an `ArgumentException`.

> [!WARNING]
> **Streaming fails over only before the first update.** If a client throws before yielding anything, the next client answers and the consumer never notices. Once an update has been delivered (`OutputCommitted`), the failure is terminal: the exception surfaces *after* partial output, and no further client is tried. Consumers of a streaming failover client must tolerate a stream that ends in an exception, and a tool call the first client already executed is not undone.

## Your own failover policy

`FailoverChatClient` is the abstract base under `OrderedFailoverChatClient`. A policy is two overrides — *which client next* and *what happened*:

```csharp
using System.Runtime.CompilerServices;
using Microsoft.Extensions.AI;

sealed class RoundRobinFailover(IReadOnlyList<IChatClient> clients) : FailoverChatClient
{
    // The same RoutingContext instance flows through every call made for one request,
    // so per-request state keys on it.
    private readonly ConditionalWeakTable<RoutingContext, StrongBox<int>> _attempts = new();

    protected override ValueTask<IChatClient> SelectClientAsync(RoutingContext context, CancellationToken cancellationToken)
    {
        StrongBox<int> box = _attempts.GetValue(context, _ => new StrongBox<int>(0));
        int index = box.Value++;
        if (index >= clients.Count)
        {
            // Throw to stop. Returning null is an InvalidOperationException, not a stop signal.
            throw new InvalidOperationException("Every client failed.");
        }
        return new ValueTask<IChatClient>(clients[index]);
    }

    protected override ValueTask OnRoutingUpdateAsync(RoutingContext context, FailoverChatClientAttempt attempt, bool isTerminal, CancellationToken cancellationToken)
    {
        // Called after EVERY attempt, the successful one included (attempt.Exception is null, ResponseCompleted is true).
        // isTerminal: no further attempt follows — success, output already committed, or the attempt cap reached.
        return default;
    }
}
```

- `SelectClientAsync` is called for each attempt; `OnRoutingUpdateAsync` is called after each attempt with a read-only `FailoverChatClientAttempt` — `Client`, `Exception`, `Duration`, `TimeToFirstUpdate` (set only once a stream has yielded), `OutputCommitted`, `ResponseCompleted`. The type has no public constructor (CS1729); you read it, you do not build it.
- Both members are `protected` (CS0122 from outside), so a public-members dump does not list them — they are real, and they are the whole API of a policy.
- `MaximumAttemptsPerRequest` is enforced by the base class for your policy too; the attempt that hits the cap arrives with `isTerminal` true.
- `OrderedFailoverChatClient` rethrows the last client's exception on exhaustion. To do the same, remember `attempt.Exception` in `OnRoutingUpdateAsync` and throw it from `SelectClientAsync` when you run out — whatever `SelectClientAsync` throws surfaces to the caller unchanged.

## Engineering guidance

- **Put middleware where its scope is.** Above the router: one cache, one tool loop, one telemetry span for whichever client is chosen. Inside a candidate: the layers that differ per candidate (a different tool set, a provider-specific option).
- **Failover is not free of side effects.** Tool calls executed by a client that then failed have happened; make tool implementations idempotent or keep function invocation above the failover client so the loop is driven once.
- **Profile phrases are the routing table.** Write them the way users write, and re-check routing when you change them — the score is an aggregate over the top-K phrases, so adding phrases under `Sum` inflates a client's score.
- **Keep `MEAI001` suppression local** to the project that owns the router, and re-verify these types on every package update — experimental means the shape may change without a major version.

## ✅ Review checklist

- `MEAI001` is suppressed deliberately and only where a gated type is used.
- Selectors null-check `RoutingContext.ChatOptions`.
- Streaming consumers of a failover client tolerate partial output followed by an exception.
- `leaveOpen` matches who owns the candidates — and, for semantic routing, who owns the embedding generator.
- Custom policies throw on exhaustion rather than returning `null`, and key per-request state on the `RoutingContext`.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28; every code fence re-compiled the same day in the whole-skill fence harness). The `MEAI001` gate, the constructor defaults, the null `ChatOptions`, the last-exception rethrow, the no-failover-after-first-update rule, the last-user-message embedding, the global top-K aggregation and the dispose semantics are execution facts; `SelectClientAsync` and `OnRoutingUpdateAsync` are protected members a public-members dump cannot show, proven by CS0534 and CS0122.*
