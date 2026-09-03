# 🔁 Autonomous Agent Loops: `LoopAgent` & Evaluators (v1.20)

`LoopAgent` wraps any `AIAgent` (it derives from `DelegatingAIAgent`) and re-invokes it until a `LoopEvaluator` decides the task is complete or `MaxIterations` is reached. Evaluator feedback is injected into the next iteration. The core family is unchanged since v1.11 (v1.12 added `BackgroundTaskCompletionLoopEvaluator`) and is **byte-identical from v1.13 through v1.20** by mechanical surface diff.

> [!WARNING]
> This entire API family is marked **experimental** — compiling against it raises diagnostic **`MAAI001`** ("for evaluation purposes only and is subject to change or removal"). Suppress it deliberately: `<NoWarn>$(NoWarn);MAAI001</NoWarn>` in the project, or `#pragma warning disable MAAI001` at the call site.

---

## 🏛️ Core Types

* **`LoopAgent`** — constructors: `LoopAgent(AIAgent innerAgent, LoopEvaluator evaluator, LoopAgentOptions options, ILoggerFactory loggerFactory)` and `LoopAgent(AIAgent innerAgent, IEnumerable<LoopEvaluator> evaluators, LoopAgentOptions options, ILoggerFactory loggerFactory)`.
* **`LoopAgentOptions`** — `Nullable<int> MaxIterations`, `bool FreshContextPerIteration`, `string OnBehalfOfAuthorName`, `bool ExcludeOnBehalfOfMessages`, `bool NonStreamingReturnsLastResponseOnly`, `Func<AgentSession, CancellationToken, ValueTask> SessionCreatedCallback`.
* **`LoopEvaluator`** (abstract) — override `ValueTask<LoopEvaluation> EvaluateAsync(LoopContext context, CancellationToken cancellationToken)`.
* **`LoopEvaluation`** — factory results: `LoopEvaluation.Stop()`, `LoopEvaluation.Continue(string feedback)`, `LoopEvaluation.ContinueWithMessages(IEnumerable<ChatMessage> messages)`; exposes `bool ShouldReinvoke`, `string Feedback`.
* **`LoopContext`** — `AIAgent Agent`, `AgentSession Session`, `IReadOnlyList<ChatMessage> InitialMessages`, `AgentRunOptions RunOptions`, `int Iteration`, `AgentResponse LastResponse`, `IReadOnlyList<string> Feedback`, `AdditionalPropertiesDictionary AdditionalProperties`.

## 🧰 Built-in Evaluators

| Evaluator | Constructor | Options |
|---|---|---|
| `AIJudgeLoopEvaluator` | `(IChatClient judgeClient, AIJudgeLoopEvaluatorOptions options)` | `Instructions`, `IEnumerable<string> Criteria`, `FeedbackMessageTemplate` |
| `CompletionMarkerLoopEvaluator` | `(string completionMarker, CompletionMarkerLoopEvaluatorOptions options)` | `FeedbackMessageTemplate` |
| `TodoCompletionLoopEvaluator` | `(TodoCompletionLoopEvaluatorOptions options)` | `IEnumerable<string> Modes`, `FeedbackMessageTemplate` |
| `BackgroundTaskCompletionLoopEvaluator` **(added in v1.12)** | `(BackgroundTaskCompletionLoopEvaluatorOptions options)` | `FeedbackMessageTemplate` |
| `DelegateLoopEvaluator` | `(Func<LoopContext, CancellationToken, ValueTask<LoopEvaluation>> evaluate)` | — |

`RubricScore` (`Id`, `Nullable<int> Score`, `Applicable`, `Weight`, `Reason`) is the record used for judge-style scoring output.

## 🛠️ Compile-Verified Example

Keep an agent looping until its spawned background tasks finish:

```csharp
using Microsoft.Agents.AI;

var bgEval = new BackgroundTaskCompletionLoopEvaluator(new BackgroundTaskCompletionLoopEvaluatorOptions
{
    FeedbackMessageTemplate = "Background tasks still running: {0}"
});

var loopAgent = new LoopAgent(
    workerAgent,
    bgEval,
    new LoopAgentOptions { MaxIterations = 10 },
    loggerFactory);
```

The resulting `loopAgent` is an `AIAgent` — run it directly or bind it into a workflow via `AIAgentBinding` like any other agent.

## 🧭 Choosing the right primitive

Use a loop when one agent repeatedly produces and evaluates a result. Use a workflow when the system needs typed handoffs, fan-out/fan-in, durable checkpoints, or human requests. If both are needed, wrap the bounded loop as one stage of the workflow rather than recreating workflow routing inside the loop.

For a *manager-led* loop over several participants, the Magentic orchestration builder is the shipped primitive, and its manager prompts are customizable from v1.16 onward. Reach for it before hand-rolling a planner loop; see [Human-in-the-Loop and Routing](hitl-and-routing.md).

A workflow that must be driven like an agent — sessions, `RunAsync`, serialization — is hosted with `AsAIAgent`; see [Workflow Hosting](workflow-hosting.md) for the chat-protocol requirement and the v1.19 checkpoint controls that come with it.

## 🛠️ Engineering guidance

- Treat `LoopAgent` as an agent-layer orchestration primitive, not as a replacement for a typed workflow graph.
- Keep a hard iteration bound even when an evaluator can terminate the loop; the bound is the failure-safe for evaluator errors, ambiguous outputs, and non-converging tasks.
- A loop wrapped in a `ToolApprovalAgent` has a second bound since v1.18: the auto-approval cap (see [Agent Skills, Files, and Tool Approval](agent-skills.md)). The two limit different things and neither substitutes for the other.
- Make the evaluator's success condition narrow and observable. Record why the loop stopped, not only that it stopped.
- Preserve the same `AgentSession` when iterations must share conversational state. Start a new session when isolation is the intended boundary. A session-routed chat client keeps its route across those iterations — the route is session state, not per-call state.
- Put irreversible tools behind explicit approval. A loop's autonomy does not weaken the host's approval policy.
- Propagate cancellation from the host through the loop and the wrapped agent calls.

## ✅ Review checklist

1. The iteration limit is explicit and covered by a test.
2. The termination evaluator has positive and negative cases.
3. Session reuse or isolation is intentional.
4. Tool approval and cancellation behavior are preserved on every iteration.
5. Telemetry distinguishes successful completion, iteration exhaustion, cancellation, and failure.

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The loop-agent surface is byte-identical from v1.13 through v1.20 by mechanical diff. **Provenance:** the type and evaluator signatures above were compile-tested against pinned **1.12.0** (surface-verified on 1.13.0, 2026-07-07) and are carried here on that byte-identity, not re-executed on 1.19.0 or 1.20.0. Consolidated into this folder on 2026-09-01 from the v1.13 and v1.14 guides; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
