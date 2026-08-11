# 🕸️ Orchestration Patterns (v1.11)

Four shipped multi-agent topologies — **sequential**, **concurrent**, **group chat**, and **handoff** — plus the static facade that builds them. Reach for these before hand-rolling executors and edges: a topology you can express here is one you do not have to wire, checkpoint, or debug yourself.

For single-agent iteration see [Agent Loops](agent-loops.md). The fifth topology — manager-led planning — is reachable here via `CreateMagenticBuilderWith`, but **its own guide exists only from v1.16**; see [the v1.16 routing guide](../v1.16/hitl-and-routing.md), noting its prompt-customization API is v1.16+ and `MAAI001`-gated.

> [!IMPORTANT]
> **`AgentWorkflowBuilder` is the entry point, and it is a `static` class.** Every topology is reached either through a one-call build method (`BuildSequential`, `BuildConcurrent`) or a factory that hands you a builder (`CreateSequentialBuilderWith`, `CreateConcurrentBuilderWith`, `CreateGroupChatBuilderWith`, `CreateHandoffBuilderWith`, `CreateMagenticBuilderWith`). The four topology builder types are `sealed` (`MagenticWorkflowBuilder` is not), and `GroupChatWorkflowBuilder` has **no public constructor at all** — its surface block carries no `Constructors:` section, and the analyzer emits one whenever any public constructor exists, so this covers every arity. `new GroupChatWorkflowBuilder(...)` fails with **CS1729**. Go through the facade.

## 🚪 The Facade

```csharp
using System.Linq;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

// One call, no builder -- when defaults are enough.
Workflow sequential = AgentWorkflowBuilder.BuildSequential(agents);
Workflow concurrent = AgentWorkflowBuilder.BuildConcurrent(agents);

// Builder, when you need to configure.
SequentialWorkflowBuilder sb = AgentWorkflowBuilder.CreateSequentialBuilderWith(agents);
ConcurrentWorkflowBuilder cb = AgentWorkflowBuilder.CreateConcurrentBuilderWith(agents);
HandoffWorkflowBuilder    hb = AgentWorkflowBuilder.CreateHandoffBuilderWith(firstAgent);
MagenticWorkflowBuilder   mb = AgentWorkflowBuilder.CreateMagenticBuilderWith(managerAgent);
```

`BuildSequential` and `BuildConcurrent` — and only those two, not the builder factories above them — have an **overload** taking a workflow name as the first argument (an overload, not an optional parameter — the distinction this page's next warning is about); `BuildSequential` additionally takes a `chainOnlyAgentResponses` flag (**v1.11+** — v1.10 has neither that overload nor `WithChainOnlyAgentResponses`).

> [!WARNING]
> **The reflected signature of `BuildConcurrent` is misleading.** It reads as `BuildConcurrent(IEnumerable<AIAgent> agents, Func<…> aggregator)`, but **the aggregator is optional** — `BuildConcurrent(agents)` and `BuildConcurrent("name", agents)` both compile. A reflection dump renders an optional parameter identically to a required one, so the surface alone will have you writing an aggregator you do not need. The same is true of `RoundRobinGroupChatManager`'s terminate function and of every parameter of `WithAutonomousMode()`.

## 🧵 Sequential

Agents run in order, each seeing what came before.

```csharp
Workflow wf = AgentWorkflowBuilder.CreateSequentialBuilderWith(agents)
    .WithChainOnlyAgentResponses(true)   // v1.11+; pass only agent responses down the chain
    .WithName("triage-then-draft")
    .Build();
```

## 🌿 Concurrent

Agents run in parallel over the same input; an aggregator folds their results into one message list.

```csharp
Workflow wf = AgentWorkflowBuilder.CreateConcurrentBuilderWith(agents)
    .WithAggregator(results => results.SelectMany(r => r).ToList())
    .Build();
```

`WithAggregator` is optional on the builder path too — omit it to take the default fold. The aggregator's shape is `Func<IList<List<ChatMessage>>, List<ChatMessage>>`: one inner list per agent, in participant order.

## 💬 Group Chat

Participants take turns under a **manager** that decides when the conversation ends. The manager is supplied by a factory, which is why there is no public constructor.

```csharp
Workflow wf = AgentWorkflowBuilder
    .CreateGroupChatBuilderWith(participants =>
        new RoundRobinGroupChatManager(participants))
    .AddParticipants(agents)
    .Build();
```

`GroupChatManager` is `abstract` and exposes `IterationCount` and `MaximumIterationCount`; **`MaximumIterationCount` is the bound that stops a group chat running forever** — set it, or rely on a termination function. `RoundRobinGroupChatManager` also accepts an optional `shouldTerminateFunc` of shape `Func<RoundRobinGroupChatManager, IEnumerable<ChatMessage>, CancellationToken, ValueTask<bool>>`.

## 🔀 Handoff

One agent starts; agents transfer control to each other along declared edges. This is the richest builder, and **all of its methods live on the base class `HandoffWorkflowBuilderCore<TBuilder>`** — which is why the sealed type's own surface looks nearly empty.

```csharp
Workflow wf = AgentWorkflowBuilder.CreateHandoffBuilderWith(frontline)
    .WithHandoff(frontline, specialist, "needs domain expertise")
    .WithHandoffs(specialist, new[] { billing, technical })
    .WithHandoffInstructions("Transfer only when the request is outside your scope.")
    .EnableReturnToPrevious()
    .WithTerminationCondition(messages => messages.Count > 20)
    .Build();
```

Also available: `WithToolCallFilteringBehavior(HandoffToolCallFilteringBehavior)` — the enum values are `None`, `HandoffOnly`, and `All`; `EmitAgentResponseEvents` / `EmitAgentResponseUpdateEvents` to control event volume; `AddParticipants`; and `WithAutonomousMode(...)`, whose five parameters (turn limit, continuation prompt, agents, per-agent turn limits, per-agent continuation prompts) are **all optional**.

`WithTerminationCondition` has a synchronous and a `ValueTask<bool>` overload.

> [!WARNING]
> **There are two handoff builder types and both work.** `HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` — note the **`s`** — are separate `sealed` classes, both deriving `HandoffWorkflowBuilderCore<TBuilder>`, both constructible from an `AIAgent`, both compiling to a working workflow. `AgentWorkflowBuilder.CreateHandoffBuilderWith` returns the **non-`s`** one. Prefer the facade so the choice is made for you; if you see the `s` spelling in generated code it is not a typo, but it is not the documented path either.

## 🧰 Shared Configuration

Every builder here derives from `OrchestrationBuilderBase<TBuilder>`, which contributes:

| Method | Purpose |
|---|---|
| `WithName(string)` | names the workflow |
| `WithDescription(string)` | describes it |
| `WithOutputFrom(IEnumerable<AIAgent>)` | which agents produce workflow output |
| `WithIntermediateOutputFrom(IEnumerable<AIAgent>)` | which agents emit intermediate output |

Because these live on the base, they return `TBuilder` and chain in any order with the topology-specific methods above.

## 🧭 Choosing a Topology

| You need… | Use |
|---|---|
| A fixed pipeline, each step seeing the last | **sequential** |
| The same input answered several ways, then merged | **concurrent** |
| Participants conversing under a turn/termination policy | **group chat** |
| Control transferring along declared edges, possibly returning | **handoff** |
| A manager planning over participants | Magentic — documented from v1.16; see [the v1.16 routing guide](../v1.16/hitl-and-routing.md) |
| One agent iterating on its own output | [Agent Loops](agent-loops.md) |

---
*Verified against MAF v1.11.0 DLL surface (2026-08-10). The optionality claims were compile-tested against pinned **1.17.0** only; the surface dump renders no parameter defaults, so byte-identity across versions cannot carry optionality and this doc does **not** assert those defaults for v1.11 specifically. The optionality of `BuildConcurrent`'s aggregator, `RoundRobinGroupChatManager`'s terminate function, and every `WithAutonomousMode` parameter are compile-test facts invisible to the surface dump; `GroupChatWorkflowBuilder`'s absent public constructor is established from the surface block carrying no `Constructors:` section, which the analyzer emits whenever any public constructor exists -- so it holds for every arity and every version dumped.*
