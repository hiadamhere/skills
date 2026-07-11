# 🔁 Autonomous Agent Loops: `LoopAgent` & Evaluators (v1.13)

`LoopAgent` wraps any `AIAgent` (it derives from `DelegatingAIAgent`) and re-invokes it until a `LoopEvaluator` decides the task is complete or `MaxIterations` is reached. Evaluator feedback is injected into the next iteration. The core family is unchanged since v1.11 (v1.12 added `BackgroundTaskCompletionLoopEvaluator`); **v1.13 makes no changes to the loop API** (verified: zero signature differences vs v1.12).

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

The resulting `loopAgent` is an `AIAgent` — run it directly or bind it into a workflow via `AIAgentBinding` like any other agent. For the judge/marker/todo/delegate evaluator patterns, the v1.11 examples apply unchanged in v1.13.

---
*Verified against MAF v1.13.0 DLL surface (2026-07-07). The loop-agent family is byte-identical to v1.12 (mechanical surface diff), so the v1.12 compile-tested samples apply unchanged.*
