# 🗺️ MAF Version Map & API Compatibility Matrix

This document maps feature availability and breaking API changes across Microsoft Agent Framework (MAF/MSAF) releases. Every cell below is **verified against the actual NuGet DLLs** (reflection surface dump + compile tests against pinned package versions), not documentation folklore. Resolve the package version from the project before selecting a reference folder.

---

## 📊 Feature Support Matrix

| Feature | v1.10 | v1.11 | v1.12 | v1.13 | v1.14 | v1.15 | v1.16 | v1.17 | v1.18 | v1.19 | Reference |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| Pregel/BSP workflow execution, executors, edges, streaming | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `SKILL.md` |
| `RequestPort` HITL and `RunStatus.PendingRequests` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/hitl-and-routing.md` |
| Scoped workflow state and checkpointing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/state-and-persistence.md` |
| Sequential / concurrent / group-chat / handoff orchestration builders | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/orchestration-patterns.md` |
| Context compaction: strategies, triggers, `CompactionProvider` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/context-compaction.md` |
| Workflow event taxonomy (21 types) and typed output | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/workflow-events.md` |
| Declarative executors: `[MessageHandler]` + `ConfigureProtocol` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/declarative-executors.md` |
| Hosting a workflow as an `AIAgent` (`WorkflowHostingExtensions.AsAIAgent`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/state-and-persistence.md` |
| `LoopAgent` and loop evaluators | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-loops.md` |
| Context-aware agent skills and tool auto-approval | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-skills.md` |
| Composable/disposable skill sources and renamed `AgentFileStore` contract | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-skills.md` |
| Contextual `ToolAutoApprovalRuleContext` rules | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-skills.md` |
| Async agent-mode state and async message injection | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-layer-core.md` |
| Approval-response binding and approval-not-required bypass middleware | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-layer-core.md` |
| `CheckpointManager.GetLatestCheckpointAsync` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.15/state-and-persistence.md` |
| `WatchStreamAsync(blockOnPendingRequest, …)` overload | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.15/production-readiness.md` |
| Magentic prompt overrides + response language (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | ⚗️ | ⚗️ | `v1.16/hitl-and-routing.md` |
| `ChatClientAgentOptions.AllowConcurrentInvocation` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | `v1.18/agent-layer-core.md` |
| `ToolApprovalAgentOptions.MaxAutoApprovalIterations` (default 40) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | `v1.18/agent-skills.md` |
| Invocable-function bypass: `EnableInvocableFunctionBypassing` / `UseInvocableFunctionBypassing` (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | `v1.18/agent-layer-core.md` |
| `BackgroundAgentsProvider.ReleaseSessionAsync` (⚗️ the type is `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | `v1.18/agent-layer-core.md` |
| `RoutePersistingRoutingChatClient` session-persisted routing (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | `v1.19/agent-layer-core.md` |
| `WorkflowAgentMetadata` + `WorkflowHostingExtensions.WithCheckpointing` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | `v1.19/state-and-persistence.md` |
| `WorkflowSessionCheckpointRecovery` (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | `v1.19/state-and-persistence.md` |
| `FeatureUsage` process-wide feature tracking (⚗️ `MAAI001`, infrastructure) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | `v1.19/agent-layer-core.md` |
| `AgentSkillsSource.GetSkillsAsync(ct)` bare-token overload + `UseScriptApproval` | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | **Removed in v1.12** — migration: `v1.12/agent-skills.md` |
| Pre-1.13 `AgentFileStore` file methods (`WriteFileAsync`/`ReadFileAsync`/`ListFilesAsync`/`SearchFilesAsync`; `ListDirectoriesAsync` from v1.11) | ✅ | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | **Renamed in v1.13** — migration: `v1.13/agent-skills.md` |
| `WorkflowSuspendedException` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **Never shipped in any release — see warning below** |

⚗️ = ships, but gated behind the `MAAI001` experimental diagnostic (a compile **error** until suppressed).
⛔ = existed in an earlier release and was **removed or renamed** — code written against it will not compile. ❌ = never present in that version.

---

## 🔑 What Actually Changes Between Versions

`Microsoft.Agents.AI.Abstractions` is API-stable across v1.10–v1.18 and gains one type in v1.19. The Workflows layer (`Microsoft.Agents.AI.Workflows`) was stable through v1.14 (v1.10 differs only by lacking the `WithChainOnlyAgentResponses` sequential-chain option), moves in v1.15 and v1.16, is unchanged in v1.17 and v1.18, and moves again in v1.19. The agent layer (`Microsoft.Agents.AI`) is where the earlier releases differ — and where v1.18 and v1.19 add again:

- **v1.10 → v1.11:** adds the autonomous loop-agent family.
- **v1.11 → v1.12:** makes skill sources and filters context-aware and introduces configurable caching and tool auto-approval.
- **v1.12 → v1.13:** adds composable skill-source decorators and disposable provider lifecycles; renames the `AgentFileStore` contract.
- **v1.13 → v1.14:** leaves `Microsoft.Agents.AI.Abstractions` and `Microsoft.Agents.AI.Workflows` byte-identical. The agent assembly changes the nested mode value from description to instructions, makes mode state and message injection asynchronous, enriches auto-approval rules with `ToolAutoApprovalRuleContext`, and replaces the old non-approval bypass surface with approval-not-required bypass and approval-response binding controls.
- **v1.14 → v1.15:** purely additive, and only in Workflows — two new members, nothing removed or renamed. `CheckpointManager.GetLatestCheckpointAsync(sessionId, cancellationToken)` resolves a session's most recent checkpoint, and `StreamingRun.WatchStreamAsync(blockOnPendingRequest, cancellationToken)` makes the stream's behavior at a pending human request an explicit host decision.
- **v1.15 → v1.16:** purely additive, and only in Workflows — Magentic manager prompt customization. `MagenticPromptOverrides` (seven `init`-only prompt slots), `MagenticDefaultPrompts` (the shipped default for each slot), and `MagenticWorkflowBuilder.WithPromptOverrides` / `.WithResponseLanguage`. **All of it is gated behind `MAAI001`** — see the trap table below.
- **v1.16 → v1.17:** **nothing at all.** The public surface of all three assemblies is *byte-identical* to v1.16 by mechanical diff — not merely additive, but unchanged: no additions, no removals, no renames. v1.16 code compiles unchanged and there is no adoption work at the API level.
- **v1.17 → v1.18:** purely additive, and only in the agent layer — Abstractions and Workflows are byte-identical to v1.17. Five members: `ChatClientAgentOptions.AllowConcurrentInvocation` (run several function calls from one response in parallel) and `EnableInvocableFunctionBypassing` (store backend calls that arrive alongside frontend calls and execute them next turn), the matching `ChatClientBuilder` extension `UseInvocableFunctionBypassing`, `ToolApprovalAgentOptions.MaxAutoApprovalIterations` (a cap on auto-approved re-invocations, default 40 via the `const` `ToolApprovalAgent.DefaultMaxAutoApprovalIterations`), and `BackgroundAgentsProvider.ReleaseSessionAsync`. The bypass pair and the background provider are `MAAI001`; the concurrency flag and the cap are not.
- **v1.18 → v1.19:** purely additive, in all three assemblies. Abstractions gains `FeatureUsage` (`MAAI001`, infrastructure). The agent layer gains `RoutePersistingRoutingChatClient` and its options (`MAAI001`) — a `Microsoft.Extensions.AI.RoutingChatClient` that picks a named inner client **per session** and persists the choice in the session's state bag. Workflows gains three hosted-workflow members: `WorkflowAgentMetadata` (identify a workflow agent through `GetService`), `WorkflowHostingExtensions.WithCheckpointing` (redirect a built agent's checkpoints into your `CheckpointManager`), and `WorkflowSessionCheckpointRecovery` (`MAAI001`; position a session on a checkpoint with `TryPrepare`). The framework's `Microsoft.Extensions.AI` dependency moves from 10.7.0 to **10.9.0**.

> [!WARNING]
> **`WorkflowSuspendedException` does not exist in any MAF version** (verified against the v1.10.0 through v1.19.0 DLL surfaces). Some pre-release documentation and LLM training data describe a suspend-by-exception HITL pattern with an `InProcessExecution.ResumeAsync(workflow, runId)` shape — that API surface was never shipped. Human-in-the-loop is modeled with `RequestPort` + `RunStatus.PendingRequests` + `Run.ResumeAsync(responses)` in **all** supported versions. If you find yourself writing `throw new WorkflowSuspendedException(...)`, stop — it will not compile.

---

## 🔀 Migration Traps in v1.14

| v1.13 shape | v1.14 replacement |
| --- | --- |
| `AgentModeProviderOptions.AgentMode(name, description)` and `.Description` | `AgentModeProviderOptions.AgentMode(name, instructions)` and `.Instructions` |
| `AgentModeProvider.GetMode` / `SetMode` | `GetModeAsync` / `SetModeAsync` with a cancellation token |
| Auto-approval rule receives `FunctionCallContent` | Rule receives `ToolAutoApprovalRuleContext`; use `.FunctionCallContent` for the call |
| `MessageInjectingChatClient.EnqueueMessages` / `GetPendingMessages` | `EnqueueMessagesAsync` / `GetPendingMessagesAsync` with a cancellation token |
| `EnableNonApprovalRequiredFunctionBypassing` | `DisableApprovalNotRequiredFunctionBypassing` |
| `UseNonApprovalRequiredFunctionBypassing` | `UseApprovalNotRequiredFunctionBypassing` — the `ILoggerFactory` parameter is **optional** (default `null`); the surface dump renders it as required |
| No approval-response binding switch | `DisableApprovalResponseBinding` and `UseApprovalResponseBinding` |

---

## 🔀 Migration Traps in v1.15 and v1.16

Neither release removes or renames anything — v1.14 code compiles unchanged on both. The traps are in *adopting* the new surface:

| Trap | Reality |
| --- | --- |
| Assuming `WatchStreamAsync(blockOnPendingRequest, …)` exists before v1.15 | It is new in v1.15. On v1.14 and earlier there is only `WatchStreamAsync(cancellationToken)`. |
| Hand-tracking the newest `CheckpointInfo` on v1.15+ | `CheckpointManager.GetLatestCheckpointAsync(sessionId)` resolves it; the token is optional. It resolves *identity*, not compatibility — still validate before resuming. |
| Assigning the result to a non-nullable `CheckpointInfo` | The return is **`CheckpointInfo?`** — a session with no checkpoints yields `null`. `CheckpointInfo latest = await …` raises CS8600 and sets up a null dereference on resume. The surface dump cannot show this; only a compile test does. |
| Writing `overrides.ProgressLedgerPrompt = "…"` after construction | `MagenticPromptOverrides` properties are **`init`-only**. Use an object initializer; the surface dump's `{ get; set; }` cannot distinguish `init` from `set`. |
| Expecting the v1.16 Magentic prompt API to just compile | It raises **`MAAI001` as an error**. Add `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. The pre-existing `MagenticWorkflowBuilder` methods are not gated. |
| Copying a default prompt once and freezing it | `MagenticDefaultPrompts` values are shipped defaults that evolve. Diff your overrides against them at every upgrade. |

---

## 🔀 Adoption Traps in v1.18 and v1.19

Neither release removes or renames anything either — v1.17 code compiles unchanged on both. The traps:

| Trap | Reality |
| --- | --- |
| Suppressing `MAAI001` for the whole v1.18 agent layer | Only `EnableInvocableFunctionBypassing`, `UseInvocableFunctionBypassing`, and `BackgroundAgentsProvider` are gated. `AllowConcurrentInvocation` and `MaxAutoApprovalIterations` compile clean — scope the suppression to what needs it. |
| Treating `AllowConcurrentInvocation` as "let the model call several tools" | That is the chat-options flag. This one decides whether the agent *executes* several returned calls in parallel. `AllowConcurrentInvocation` defaults to `false`; the chat-options flag is a nullable `bool` that defaults to `null` — the provider decides. |
| Reading `MaxAutoApprovalIterations = null` as "unbounded" | `null` means the default, `ToolApprovalAgent.DefaultMaxAutoApprovalIterations` — a `const int` of **40**. It is a constant, so a reflection dump never lists it and assigning to it is CS0131. |
| Registering `UseInvocableFunctionBypassing` above approval-response binding in a custom pipeline | Binding drops responses it never recorded; the bypass injects synthetic ones. In that order the stored calls are silently discarded. Put the bypass **below** binding, above the function-invoking client. |
| Calling `RoutePersistingRoutingChatClient` directly | It resolves the session from the running agent and throws an **InvalidOperationException** outside `RunAsync` / `RunStreamingAsync`. Route through an agent, always. |
| Routing to a route name that was never registered | `SetActiveRoute` throws an **ArgumentException**. An unregistered `DefaultRoute` is accepted by the constructor and returned by `GetActiveRoute`; the first run then throws an **InvalidOperationException** (*"No usable chat client is registered for the active route"*), and an empty routes dictionary with no default makes `GetActiveRoute` itself throw. Validation happens at selection, not construction. |
| Pinning `Microsoft.Extensions.AI` below 10.9.0 next to MAF 1.19.0 | 1.19.0 depends on 10.9.0 (1.17/1.18: 10.7.0); the routing client's base type lives there. Let the dependency float or pin at least 10.9.0. |
| Hosting any `Workflow` with `AsAIAgent` | The first `RunAsync` throws unless the start executor accepts `List<ChatMessage>` and `TurnToken` — a bare `Executor<string, string>` graph fails; a `BuildSequential` workflow qualifies (both executed against 1.14.0, 1.17.0 and 1.19.0). |
| Calling `WithCheckpointing` on a wrapped agent, or after the environment already names a manager | It returns the **same instance, unchanged**, in both cases — and for non-workflow agents. Apply it before wrapping and assert `WorkflowAgentMetadata.UsesOwnCheckpointStorage` afterwards. |
| Relying on an auto-generated agent id across `WithCheckpointing` | The copy regenerates an auto id; an explicit `id` passed to `AsAIAgent` is preserved. Pass an explicit `id`. |
| Trusting `TryPrepare` to reject an unknown checkpoint id | It does not check that the id **exists**: any well-formed id returns `true` and is selected, and the next run throws a **KeyNotFoundException**. Only the shape is checked — an empty or whitespace id throws an **ArgumentException**, and `null` keeps the current selection. Resolve and validate the id first; `GetLatestCheckpointAsync` is the shipped lookup. |
| Assigning `CurrentCheckpoint` to a non-nullable `CheckpointInfo` | It is **`CheckpointInfo?`** — `null` before the first run checkpoints. CS8600, exactly as with `GetLatestCheckpointAsync`. |
| Using recovery as rollback | It continues the work *queued* in a checkpoint. On a finished run there is nothing queued: in the probe a message-less `RunAsync(session)` after `TryPrepare` did not return within ten seconds. Put a deadline token on that call. Selecting an older checkpoint can repeat external effects. |

---

## 📂 Target Version References

- **[v1.11](v1.11/)** — for projects pinned to 1.11.x.
- **[v1.12](v1.12/)** — context-aware agent skills; for projects pinned to 1.12.x.
- **[v1.13](v1.13/)** — composable/disposable agent skills and the renamed `AgentFileStore` contract; for projects pinned to 1.13.x.
- **[v1.14](v1.14/)** — async agent modes/message injection, contextual tool auto-approval, and approval-middleware changes.
- **[v1.15](v1.15/)** — latest-checkpoint resolution and the pending-request streaming overload; for projects pinned to 1.15.x.
- **[v1.16](v1.16/)** — Magentic manager prompt overrides and response language (experimental, `MAAI001`).
- **[v1.17](v1.17/)** — API-identical to v1.16, so the folder exists to confirm there is nothing to migrate.
- **[v1.18](v1.18/)** — concurrent tool invocation, the auto-approval iteration cap, the invocable-function bypass (experimental), and background-session release; for projects pinned to 1.18.x.
- **[v1.19](v1.19/)** — **latest verified folder**; session-persisted chat-client routing (experimental), hosted-workflow checkpoint controls, and the `Microsoft.Extensions.AI` 10.9.0 dependency.

---

## ⚠️ Version Fallback & Future Rules

- **v1.10.x projects:** use the v1.11 folder for workflow guidance, but do not use the loop-agent family or the `WithChainOnlyAgentResponses` sequential chain-only option (neither exists in 1.10).
- **Versions newer than v1.19:** treat every signature as unverified until a new surface dump and compile test exist. Regenerate ground truth via the private analyzer (`--version <ver>`) before relying on new APIs.
- Do not mix newer features (composable skill sources, loop evaluators, context-aware skills, async agent modes, the v1.15 Workflows additions, Magentic prompt overrides, the v1.18 agent options, the v1.19 routing client and hosted-workflow checkpoint controls) into older-pinned codebases.
- **Experimental APIs are not a version feature you can rely on.** Anything behind `MAAI001` may change or vanish in a later minor release; isolate it behind your own seam. The gate is applied per member, not per release: a version's additions can be half gated and half not (v1.18 and v1.19 both are).

---
*Verified against MAF v1.10.0 / v1.11.0 / v1.12.0 / v1.13.0 / v1.14.0 / v1.15.0 / v1.16.0 / v1.17.0 / v1.18.0 / v1.19.0 DLL surfaces and compile tests (2026-08-27).*
