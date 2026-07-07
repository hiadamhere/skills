# 🗺️ MAF Version Map & API Compatibility Matrix

This document maps feature availability and breaking API changes across Microsoft Agent Framework (MAF/MSAF) releases. Every cell below is **verified against the actual NuGet DLLs** (reflection surface dump + compile tests against pinned package versions), not documentation folklore.

---

## 📊 Feature Support Matrix

| Feature | v1.10.x | v1.11.x | v1.12.x | Documentation Reference |
| :--- | :---: | :---: | :---: | :--- |
| **Pregel BSP execution model** | ✅ | ✅ | ✅ | `SKILL.md` |
| **`Executor<TInput, TOutput>` base class** | ✅ | ✅ | ✅ | `SKILL.md` |
| **`ExecutorBinding` system (+ implicit `Executor` → binding conversion)** | ✅ | ✅ | ✅ | `vX.X/hitl-and-routing.md` |
| **`RequestPort` HITL & `RunStatus.PendingRequests`** | ✅ | ✅ | ✅ | `vX.X/hitl-and-routing.md` |
| **Scoped state (`scopeName` overloads on `IWorkflowContext`)** | ✅ | ✅ | ✅ | `vX.X/state-and-persistence.md` |
| **Checkpointing (`CheckpointManager`, `ICheckpointStore<T>`)** | ✅ | ✅ | ✅ | `vX.X/state-and-persistence.md` |
| **`StreamingRun` & `WatchStreamAsync`** | ✅ | ✅ | ✅ | `vX.X/production-readiness.md` |
| **`AgentWorkflowBuilder` orchestrations (sequential/concurrent/handoff/group-chat/Magentic)** | ✅ | ✅ | ✅ | `v1.12/hitl-and-routing.md` |
| **`WithChainOnlyAgentResponses` / `BuildSequential(chainOnlyAgentResponses, …)`** | ❌ | ✅ | ✅ | `v1.12/hitl-and-routing.md` |
| **Agent layer: `AIAgent`, `ChatClientAgent`, `AIAgentBinding`** | ✅ | ✅ | ✅ | `vX.X/agent-layer-core.md` |
| **`LoopAgent` & loop evaluators (`AIJudgeLoopEvaluator`, `CompletionMarkerLoopEvaluator`, `TodoCompletionLoopEvaluator`, `RubricScore`)** | ❌ | ✅ | ✅ | `vX.X/agent-loops.md` |
| **Context-aware agent skills (`AgentSkillsSourceContext`, `AgentFileSkillsSource`, caching options, tool auto-approval rules, `BackgroundTaskCompletionLoopEvaluator`)** | ❌ | ❌ | ✅ | `v1.12/agent-skills.md` |
| **`AgentSkillsSource.GetSkillsAsync(ct)` + `UseScriptApproval` (legacy skill-source shapes)** | ✅ | ✅ | ❌ Removed | `v1.11/agent-skills.md` (migration: `v1.12/agent-skills.md`) |
| **`WorkflowSuspendedException`** | ❌ | ❌ | ❌ | **Never existed in any MAF release — see warning below** |

---

## 🔑 What Actually Changes Between Versions

### 1. The Workflows layer is stable
`Microsoft.Agents.AI.Workflows` has an **identical public API surface in v1.11 and v1.12** (verified: zero signature differences), and v1.10 differs only by lacking the `WithChainOnlyAgentResponses` sequential-chain option. Executors, edges, bindings, `RequestPort` HITL, scoped state, checkpointing, and streaming work the same way across all three versions. `Microsoft.Agents.AI.Abstractions` is likewise identical across v1.10–v1.12.

### 2. The Agent layer is where versions differ
* **v1.10 → v1.11:** added the autonomous-loop toolkit — `LoopAgent`, `LoopEvaluator` and its implementations (`AIJudgeLoopEvaluator`, `CompletionMarkerLoopEvaluator`, `TodoCompletionLoopEvaluator`, `DelegateLoopEvaluator`), `RubricScore`.
* **v1.11 → v1.12 (breaking for skill-source authors):** `AgentSkillsSource.GetSkillsAsync(CancellationToken)` became `GetSkillsAsync(AgentSkillsSourceContext, CancellationToken)`; `AgentSkillsProviderBuilder.UseFilter(Func<AgentSkill,bool>)` became context-aware; `UseScriptApproval(bool)` / `ScriptApproval` / `DisableCaching` bool properties were replaced by `DisableCaching()` / `UseCachingOptions(...)` / `CachingAgentSkillsSourceOptions`; added `AgentFileSkillsSource`, `BackgroundTaskCompletionLoopEvaluator`, and `ToolApprovalAgent` auto-approval rules (`AllToolsAutoApprovalRule`, `ReadOnlyToolsAutoApprovalRule`).

### 3. Graph construction: bindings and raw executors both work — in every version
`WorkflowBuilder`'s signatures accept `ExecutorBinding`, but an **implicit conversion from `Executor`** exists in v1.10, v1.11, and v1.12 alike (compile-verified). `new WorkflowBuilder(myExecutor)` and `AddEdge(execA, execB, predicate)` are legal everywhere; explicit `ExecutorBindingExtensions.BindExecutor(...)` is required only for factory/DI, lambda, sub-workflow, agent, and `RequestPort` nodes.

> [!WARNING]
> **`WorkflowSuspendedException` does not exist in any MAF version** (verified against v1.10.0, v1.11.0, and v1.12.0 DLLs). Some pre-release documentation and LLM training data describe a suspend-by-exception HITL pattern with `InProcessExecution.ResumeAsync(workflow, runId)` — that API surface was never shipped. Human-in-the-loop is modeled with `RequestPort` + `RunStatus.PendingRequests` + `run.ResumeAsync(responses)` in **all** supported versions. If you find yourself writing `throw new WorkflowSuspendedException(...)`, stop — it will not compile.

---

## 📂 Target Version References

* **[v1.11 References](v1.11/)** — same Workflows API as v1.12; use when the project pins 1.11.x.
* **[v1.12 References](v1.12/)** — latest; includes the [Agent Layer Core](v1.12/agent-layer-core.md) guide.

## ⚠️ Version Fallback & Future Rules
* **v1.10.x projects:** use the v1.11 folder — the Workflows API is identical except `WithChainOnlyAgentResponses` (absent in 1.10); the agent layer lacks the `LoopAgent`/evaluator family (see matrix).
* **Versions newer than v1.12:** load the `v1.12` folder but treat any signature not listed in the matrix as unverified; regenerate ground truth via the private analyzer (`--version <ver>`) before relying on new APIs.
* Do not mix newer agent-layer features (loop evaluators, context-aware skills) into older-pinned codebases.

---
*Verified against MAF v1.10.0 / v1.11.0 / v1.12.0 DLL surfaces and compile tests (2026-07-03).*
