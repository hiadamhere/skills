# 🔁 Autonomous Agent Loops: `LoopAgent` & Evaluators (v1.11)

Introduced in v1.11, `LoopAgent` wraps any `AIAgent` (it derives from `DelegatingAIAgent`) and re-invokes it until a `LoopEvaluator` decides the task is complete or `MaxIterations` is reached. Evaluator feedback is injected into the next iteration.

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
| `DelegateLoopEvaluator` | `(Func<LoopContext, CancellationToken, ValueTask<LoopEvaluation>> evaluate)` | — |

`RubricScore` (`Id`, `Nullable<int> Score`, `Applicable`, `Weight`, `Reason`) is the record used for judge-style scoring output.

## 🛠️ Compile-Verified Example

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

var judgeEval = new AIJudgeLoopEvaluator(judgeChatClient, new AIJudgeLoopEvaluatorOptions
{
    Instructions = "Judge task completion strictly.",
    Criteria = new[] { "All requirements addressed", "No TODOs left" },
    FeedbackMessageTemplate = "Not done: {0}"
});
var markerEval = new CompletionMarkerLoopEvaluator("<<DONE>>", new CompletionMarkerLoopEvaluatorOptions());
var todoEval   = new TodoCompletionLoopEvaluator(new TodoCompletionLoopEvaluatorOptions { Modes = new[] { "strict" } });
var lambdaEval = new DelegateLoopEvaluator((ctx, ct) =>
    new ValueTask<LoopEvaluation>(ctx.Iteration >= 5 ? LoopEvaluation.Stop() : LoopEvaluation.Continue("keep going")));

var loopAgent = new LoopAgent(
    workerAgent,
    new LoopEvaluator[] { judgeEval, markerEval, todoEval, lambdaEval },
    new LoopAgentOptions { MaxIterations = 8, NonStreamingReturnsLastResponseOnly = true },
    loggerFactory);
```

The resulting `loopAgent` is an `AIAgent` — run it directly or bind it into a workflow via `AIAgentBinding` like any other agent.

> [!NOTE]
> `BackgroundTaskCompletionLoopEvaluator` does **not** exist in v1.11 — it was added in v1.12 (see the version map).

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03). All code samples compile-tested against the pinned 1.11.0 packages.*
