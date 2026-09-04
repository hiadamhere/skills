# 🗜️ Context Compaction (v1.20)

A long-running agent's chat history grows until it no longer fits the model's context window. `Microsoft.Agents.AI.Compaction` is the shipped answer: **strategies** that decide what to drop or summarise, **triggers** that decide when, and a **provider** that plugs the pair into an agent so compaction happens on its own rather than in your run loop.

Reach for this before writing your own trimming code. Hand-rolled truncation is where tool-call pairs get orphaned and system messages vanish.

> [!IMPORTANT]
> **The whole namespace is unchanged from v1.10 through v1.20** — 15 types, byte-identical by mechanical surface diff across all eleven dumped versions. The probe program behind this page compiles unmodified against pinned **1.11.0, 1.14.0 and 1.17.0**, so the optional-parameter forms below hold across the range rather than only at the newest end.

## 🧱 The Shape

Three pieces, composed:

| Piece | What it is | Examples |
|---|---|---|
| `CompactionTrigger` | a **delegate** — `bool Invoke(CompactionMessageIndex)` — asking "compact now?" | `CompactionTriggers.TokensExceed(100_000)` |
| `CompactionStrategy` | `abstract` base; decides **what** to remove or rewrite | `SlidingWindowCompactionStrategy`, `SummarizationCompactionStrategy` |
| `CompactionProvider` | an `AIContextProvider` that runs a strategy against an agent's history | `new CompactionProvider(strategy)` |

## ⏱️ Triggers

`CompactionTriggers` is a static factory of ready-made conditions:

```csharp
using Microsoft.Agents.AI.Compaction;

CompactionTrigger byTokens   = CompactionTriggers.TokensExceed(100_000);
CompactionTrigger byMessages = CompactionTriggers.MessagesExceed(50);
CompactionTrigger byTurns    = CompactionTriggers.TurnsExceed(10);
CompactionTrigger byGroups   = CompactionTriggers.GroupsExceed(20);
CompactionTrigger hasTools   = CompactionTriggers.HasToolCalls();

// All / Any take params -- no array ceremony.
CompactionTrigger both = CompactionTriggers.All(byTokens, hasTools);
CompactionTrigger either = CompactionTriggers.Any(byMessages, byTurns);
```

`TokensBelow(int)` is the mirror of `TokensExceed` and exists to serve as a **target**: several strategies take a second trigger meaning "keep compacting until this is true".

Because `CompactionTrigger` is a delegate, a lambda works anywhere one is expected:

```csharp
CompactionTrigger custom = index => index.IncludedTokenCount > index.TotalTokenCount / 2;
```

## 🧮 Strategies

Every strategy takes its trigger first; the remaining parameters are **optional**, so the minimal form is one argument.

```csharp
// Keep the last N turns, drop older ones.
var sliding = new SlidingWindowCompactionStrategy(byTokens);

// Drop the oldest groups outright.
var truncation = new TruncationCompactionStrategy(byTokens);

// Replace tool results with a short placeholder, keeping the call visible.
var toolResults = new ToolResultCompactionStrategy(hasTools);

// Budget-aware: derives an input budget from window and output sizes.
var window = new ContextWindowCompactionStrategy(128_000, 4_096);

// Summarise older history with a model instead of dropping it.
var summarizing = new SummarizationCompactionStrategy(chatClient, byTokens);

// Run several in order.
var pipeline = new PipelineCompactionStrategy(new CompactionStrategy[] { toolResults, sliding });
```

`ContextWindowCompactionStrategy` exposes the derived `InputBudgetTokens` alongside `MaxContextWindowTokens` and `MaxOutputTokens`, plus `ToolEvictionThreshold` and `TruncationThreshold` (both optional constructor parameters). `SummarizationCompactionStrategy` surfaces its `SummarizationPrompt` and `MinimumPreservedGroups`; `SlidingWindowCompactionStrategy` its `MinimumPreservedTurns`.

> [!WARNING]
> **`ToolResultCompactionStrategy.ToolCallFormatter` is `init`-only, despite reflecting as `{ get; set; }`.** Assigning it after construction fails with **CS8852**; an object initializer is the only way in. Reflection cannot distinguish an `init` accessor from a `set` accessor, so the surface dump shows a settable property that is not one. Use `ToolResultCompactionStrategy.DefaultToolCallFormatter` as the reference implementation.
>
> ```csharp
> var toolResults = new ToolResultCompactionStrategy(hasTools)
> {
>     ToolCallFormatter = g => $"[{g.MessageCount} tool messages elided]",
> };
> ```

## 🔌 Attaching It

`CompactionProvider` is an `AIContextProvider`. Its `stateKey` and `loggerFactory` parameters are optional, so one argument is enough.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

var provider = new CompactionProvider(pipeline);

// On the agent's options ...
var options = new ChatClientAgentOptions
{
    Name = "researcher",
    AIContextProviders = new AIContextProvider[] { provider },
};
AIAgent agent = new ChatClientAgent(chatClient, options);

// ... or through the chat-client builder.
builder.UseAIContextProviders(provider);
```

> [!WARNING]
> **`AIAgentBuilder.UseAIContextProviders` will not take it.** That overload's parameter is `MessageAIContextProvider[]`, and `CompactionProvider` derives from `AIContextProvider` — passing one fails with **CS1503**. The name is shared by two different methods with two different parameter types; the one that accepts a `CompactionProvider` is `ChatClientBuilder.UseAIContextProviders`. Note also that `ChatClientAgentOptions` has **no `Instructions` property** (CS0117) — instructions are set elsewhere on the agent.

For a one-off compaction with no provider, `CompactionProvider.CompactAsync(strategy, messages, logger, cancellationToken)` is `static` and returns the compacted message list.

## 📇 The Index

A strategy does not see raw messages. It sees a `CompactionMessageIndex`: messages bucketed into `CompactionMessageGroup`s, each tagged with a `CompactionGroupKind` (`System`, `User`, `AssistantText`, `ToolCall`, `Summary`), each carrying `MessageCount`, `ByteCount`, `TokenCount` and a nullable `TurnIndex`.

Compaction is expressed by **marking**, not deleting: set `IsExcluded` and `ExcludeReason` on a group. The index then reports both totals (`TotalTokenCount`, `TotalMessageCount`, `TotalTurnCount`) and post-exclusion figures (`IncludedTokenCount`, `IncludedMessageCount`, `IncludedTurnCount`, `IncludedNonSystemGroupCount`), which is what a **target** trigger tests to decide whether to keep going. `GetIncludedMessages()`, `GetAllMessages()` and `GetTurnGroups(int)` read it back; `AddGroup` and `InsertGroup` write to it, which is how a summarising strategy puts its summary back.

## 🛠️ Writing Your Own

> [!WARNING]
> **`CompactAsync` is not the extension point.** It is public but not `virtual`, so overriding it fails with **CS0506**. The member you implement is `protected abstract CompactCoreAsync(CompactionMessageIndex, ILogger, CancellationToken)` — which **never appears in the surface dump**, because the analyzer emits public members only. The base constructor is likewise `protected` and **requires a trigger** (CS7036). A reader working from the reflected surface alone cannot discover either fact.

```csharp
sealed class DropFailedToolCalls : CompactionStrategy
{
    public DropFailedToolCalls(CompactionTrigger trigger) : base(trigger) { }

    protected override ValueTask<bool> CompactCoreAsync(
        CompactionMessageIndex index,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        foreach (CompactionMessageGroup group in index.Groups)
        {
            if (group.Kind == CompactionGroupKind.ToolCall)
            {
                group.IsExcluded = true;
                group.ExcludeReason = "failed tool call";
            }
        }
        return ValueTask.FromResult(true);   // true = the index changed
    }
}
```

## 🔗 Reducers

`ChatReducerCompactionStrategy` wraps an `IChatReducer` from `Microsoft.Extensions.AI`, so an existing reducer becomes a compaction strategy without rewriting. `ChatStrategyExtensions.AsChatReducer(strategy)` goes the other way, exposing a strategy where an `IChatReducer` is expected.

## 🧭 Choosing a Strategy

| You need… | Use |
|---|---|
| A hard cap on history length | `SlidingWindowCompactionStrategy` |
| The cheapest possible drop | `TruncationCompactionStrategy` |
| Tool noise gone, calls still legible | `ToolResultCompactionStrategy` |
| Old context kept in meaning, not in tokens | `SummarizationCompactionStrategy` |
| A budget derived from the model's window | `ContextWindowCompactionStrategy` |
| Several of the above, in order | `PipelineCompactionStrategy` |
| An existing `IChatReducer` reused | `ChatReducerCompactionStrategy` |

## 🔀 Interaction with v1.19 session routing

Compaction operates on the agent's session history. With a session-routed chat client (see [Agent Middleware and Routing](agent-middleware.md)) that history is shared across routes by design, so a compaction decision made while one route was active is what the next route sees — one more reason the routes must all use client-side history.

For single-agent iteration see [Agent Loops](agent-loops.md); for the orchestration builders see [Orchestration Patterns](orchestration-patterns.md).

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The `Microsoft.Agents.AI.Compaction` namespace is byte-identical across all dumped versions (v1.10–v1.20) by mechanical diff, so the 1.20.0 surface this page targets is unchanged. **Provenance of the compile-test facts:** the optional-parameter forms, the `init`-only `ToolCallFormatter` (CS8852), the `protected abstract CompactCoreAsync` override target and `protected` base constructor (CS0506/CS0534/CS7036), the `params` behaviour of `All`/`Any`, the lambda conversion to `CompactionTrigger`, and the `AIAgentBuilder.UseAIContextProviders` rejection (CS1503) were established by a probe compiled against pinned **1.11.0, 1.14.0 and 1.17.0**, and are asserted **from those compiles** — not from the 1.19.0 or 1.20.0 dumps. A surface dump renders no parameter defaults, no `init` accessors and no protected members, so byte-identity between two dumps cannot carry any of them; the newest pin these were compiled against is 1.17.0. Consolidated into this folder on 2026-09-01 from the v1.11 guide; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated. Re-compiled on 2026-09-03: the trigger, strategy, provider-attachment and `CompactCoreAsync` override samples on this page were built against pinned **1.20.0** in the catalog's private compile harness (`probe-visualizer-views`), so the newest pin those samples are known to compile against is now 1.20.0; the compile-ERROR facts (CS8852, CS0506, CS7036, CS1503) still rest on the 1.11.0/1.14.0/1.17.0 probe.*
