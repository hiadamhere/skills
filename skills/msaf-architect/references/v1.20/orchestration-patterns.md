# 🕸️ Orchestration Patterns (v1.20)

Four shipped multi-agent topologies — **sequential**, **concurrent**, **group chat**, and **handoff** — plus the static facade that builds them. Reach for these before hand-rolling executors and edges: a topology you can express here is one you do not have to wire, checkpoint, or debug yourself.

For single-agent iteration see [Agent Loops](agent-loops.md). The fifth topology — manager-led planning — is reachable here via `CreateMagenticBuilderWith`; its manager, prompt customization and `MAAI001` gate are in [Human-in-the-Loop and Routing](hitl-and-routing.md).

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

`BuildSequential` and `BuildConcurrent` — and only those two, not the builder factories above them — have an **overload** taking a workflow name as the first argument (an overload, not an optional parameter — the distinction this page's next warning is about); `BuildSequential` additionally takes a `chainOnlyAgentResponses` flag (present since v1.11 — v1.10 has neither that overload nor `WithChainOnlyAgentResponses`).

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
| A manager planning over participants | Magentic — see [Human-in-the-Loop and Routing](hitl-and-routing.md) |
| One agent iterating on its own output | [Agent Loops](agent-loops.md) |

## 🔗 Three facts that sit next to this layer

- A `BuildSequential` workflow **speaks the chat protocol**, which is what `AsAIAgent` requires to host one as an agent (executed; the other builders were not run through `AsAIAgent`). A hand-built graph over a bare `Executor<string, string>` does not qualify — see [Workflow Hosting](workflow-hosting.md).
- A participant built with `AllowConcurrentInvocation = true` (see [Agent Middleware and Routing](agent-middleware.md)) runs its own tool calls in parallel *inside* its turn. That does not change the topology's ordering between participants — sequential is still sequential — but it does mean that participant's tools must be safe to run alongside each other.
- A participant whose chat client routes per session (see [Agent Middleware and Routing](agent-middleware.md)) keeps its route for the whole orchestration, because the route is stored in *that participant's* session.

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The orchestration surface — `AgentWorkflowBuilder`, the four topology builders, `OrchestrationBuilderBase<TBuilder>`, `HandoffWorkflowBuilderCore<TBuilder>`, the group-chat managers and `MagenticWorkflowBuilder` — is byte-identical from v1.11 through v1.20 by mechanical diff. The chat-protocol requirement was established by executing `AsAIAgent` over a `BuildSequential` workflow and over a bare executor graph against the pinned 1.19.0 packages. **Provenance of the optionality claims:** `BuildConcurrent`'s aggregator, `RoundRobinGroupChatManager`'s terminate function and every `WithAutonomousMode` parameter were compile-tested against pinned **1.17.0** only — a surface dump renders no parameter defaults, so byte-identity cannot carry optionality, and these are asserted from that compile rather than from the 1.19.0 or 1.20.0 dumps. `GroupChatWorkflowBuilder`'s absent public constructor is established from its surface block carrying no `Constructors:` section, which the analyzer emits whenever any public constructor exists, so it holds for every arity and every version dumped. Consolidated into this folder on 2026-09-01 from the v1.11 guide; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
