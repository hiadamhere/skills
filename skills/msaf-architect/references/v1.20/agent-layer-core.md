# 🧠 Agent Layer Core (v1.20)

MAF separates into two layers:

1. **Workflows layer** — the Pregel-style graph (executors, edges, supersteps) that drives execution.
2. **Agent layer** — the execution nodes (`AIAgent`) that wrap models and tools to do conversational work.

This page covers constructing an agent, managing its session, and binding it into a workflow graph. Everything that *decorates* an agent's chat client — approval middleware, the invocable-function bypass, concurrent invocation, session-persisted routing — is in [Agent Middleware and Routing](agent-middleware.md).

---

## 🏛️ `AIAgent` and `ChatClientAgent`

`AIAgent` is the abstract base for all model-driven actors. The standard concrete implementation is `ChatClientAgent`, wrapping an `IChatClient` (from `Microsoft.Extensions.AI`) with instructions and tools.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging;

var agent = new ChatClientAgent(
    chatClient: myChatClient,          // IChatClient (OpenAI, Ollama, Azure OpenAI, …)
    instructions: "You are a helpful data analyst helper.",
    name: "DataAnalyst",
    description: "Analyzes tabular data and extracts metrics.",
    tools: new List<AITool> { myCalculationsTool },
    loggerFactory: myLoggerFactory,
    services: myServiceProvider
);
```

## 💬 Conversational state: `AgentSession`

Agents hold no conversation history internally. History and custom variables live in an `AgentSession` — a `ChatClientAgentSession` when using chat clients — with arbitrary state in its `AgentSessionStateBag`.

```csharp
// 1. Create a session for a conversation
AgentSession session = await agent.CreateSessionAsync("conv-id-123", cancellationToken);

// 2. Access state variables safely
AgentSessionStateBag bag = session.StateBag;
bag.SetValue("user_tier", "premium", jsonOptions);

if (bag.TryGetValue<string>("user_tier", out var tier, jsonOptions))
{
    Console.WriteLine($"Active Tier: {tier}");
}
```

Serialize a session with `agent.SerializeSessionAsync(session, jsonOptions, cancellationToken)` and restore it later; the state bag round-trips with it, which is what lets a routed agent keep its route across a restart.

## ⚡ Agent modes are asynchronous

`AgentMode` is the nested type `AgentModeProviderOptions.AgentMode`. Its second constructor argument and property carry **instructions**, not a description. Dispose the provider, and await every mode-state access.

```csharp
using Microsoft.Agents.AI;

var options = new AgentModeProviderOptions
{
    Modes =
    [
        new AgentModeProviderOptions.AgentMode(
            "review",
            "Review the proposed change and report concrete defects.")
    ],
    DefaultMode = "review"
};

using var provider = new AgentModeProvider(options);
await provider.SetModeAsync(session, "review", cancellationToken);
string currentMode = await provider.GetModeAsync(session, cancellationToken);
```

## 📨 Message injection is asynchronous

```csharp
await injectingClient.EnqueueMessagesAsync(session, messages, cancellationToken);
IReadOnlyList<ChatMessage> pending =
    await injectingClient.GetPendingMessagesAsync(session, cancellationToken);
```

## 🔗 Binding an agent into a workflow

To place an `AIAgent` inside a Pregel graph, wrap it in an `AIAgentBinding`. It inherits from `ExecutorBinding`, so it is an ordinary executor node you can pass to `builder.AddEdge()`.

`AIAgentHostOptions` configures how the host bridges the agent to the graph's channels:

* `EmitAgentResponseEvents` — emit `AgentResponseEvent` into the workflow event stream when the agent finishes a turn.
* `EmitAgentUpdateEvents` (`Nullable<bool>`) — emit `AgentResponseUpdateEvent` token-streaming events; required for streaming UIs.
* `ForwardIncomingMessages` — forward incoming workflow messages into the agent's prompt context.
* `InterceptUnterminatedFunctionCalls` — resolve tool-execution iterations before yielding.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

var agentBinding = new AIAgentBinding(
    agent,
    new AIAgentHostOptions
    {
        EmitAgentResponseEvents = true,
        ForwardIncomingMessages = true
    }
);

var builder = new WorkflowBuilder(inputNodeBinding)
    .AddEdge(inputNodeBinding, agentBinding)
    .WithOutputFrom(agentBinding);
```

## 🛠️ Complete integration example

Define an agent, bind it, run it, and persist its session:

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging.Abstractions;
using System.Text.Json;

var reviewerAgent = new ChatClientAgent(
    chatClient: chatClient,
    instructions: "You review and format summaries. Be concise.",
    name: "SummaryReviewer",
    description: "Reviews summaries for grammar and flow.",
    tools: Array.Empty<AITool>(),
    loggerFactory: NullLoggerFactory.Instance,
    services: null);

var reviewerBinding = new AIAgentBinding(
    reviewerAgent,
    new AIAgentHostOptions { EmitAgentResponseEvents = true, ForwardIncomingMessages = true });

Workflow workflow = new WorkflowBuilder(reviewerBinding)
    .WithOutputFrom(reviewerBinding)
    .Build();

AgentSession session = await reviewerAgent.CreateSessionAsync(conversationId, CancellationToken.None);

Run run = await InProcessExecution.RunAsync(
    workflow, new ChatMessage(ChatRole.User, userInput), conversationId, CancellationToken.None);

if (await run.GetStatusAsync() == RunStatus.Ended)
{
    // There is no GetOutputsAsync() -- filter NewEvents instead.
    foreach (var evt in run.NewEvents.OfType<WorkflowOutputEvent>())
    {
        Console.WriteLine($"Workflow Output: {evt.As<ChatMessage>()?.Text}");
    }

    JsonElement stateJson =
        await reviewerAgent.SerializeSessionAsync(session, new JsonSerializerOptions(), CancellationToken.None);
    // Persist stateJson ...
}
```

> [!IMPORTANT]
> **There is no `GetOutputsAsync()`.** A finished run's output is read by filtering `run.NewEvents` for `WorkflowOutputEvent` — and `WorkflowOutputEvent` must be the **last** `case` in any `switch` over events, because `AgentResponseEvent` and `AgentResponseUpdateEvent` derive from it. See [Workflow Events](workflow-events.md).

## 🛠️ Engineering guidance

- Pin the agent, abstractions, and workflows packages to the same `1.20.0` version; the three ship in lockstep, and 1.19.0 and 1.20.0 both require `Microsoft.Extensions.AI` 10.9.0 or later.
- Keep agent identity, session identity, and run identity distinct in logs. Recovery and audit questions are asked in terms of all three; a routed agent adds the active route as a fourth dimension worth recording per turn.
- An agent passed as a Magentic *manager* is an ordinary `AIAgent`; the orchestration behavior lives in the builder, not in a special agent type.
- The v1.14 async migration is still the live one: await mode reads/writes and message injection, and propagate cancellation through both.
- Session reuse or isolation is intentional at every call site. A single session must not be used concurrently.

## ✅ Review checklist

- Agent, session and run identities are distinct in logs and telemetry.
- Mode access and message injection are awaited, with cancellation propagated.
- Session reuse or isolation is intentional; no session is used concurrently.
- Session state that must survive a restart is serialized, and the round trip is tested.
- Output is read from `WorkflowOutputEvent` with the case-order rule respected.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). The core `AIAgent`, `ChatClientAgent`, `AgentSession` and `AIAgentBinding` surfaces are byte-identical from v1.17 through v1.20 by mechanical diff. **Provenance:** the construction, session, binding and integration samples were compile-tested on pinned **1.12.0** (surface-verified 1.13.0); the asynchronous mode and message-injection contract on **1.14.0**, where the optional `ILoggerFactory` was re-verified by compile test on 2026-08-27 — optionality is asserted from that compile, since a dump renders no parameter defaults and byte-identity therefore cannot carry it. Consolidated into this folder on 2026-09-01 from the v1.13, v1.14 and v1.18 guides, and split from [Agent Middleware and Routing](agent-middleware.md) to keep each page inside the per-page budget; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
