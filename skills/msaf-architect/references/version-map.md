# 🗺️ MAF Version Map & API Compatibility Matrix

This document maps feature availability and breaking API changes across Microsoft Agent Framework (MAF/MSAF) releases. Every cell below is **verified against the actual NuGet DLLs** (reflection surface dump + compile tests against pinned package versions), not documentation folklore. Resolve the package version from the project, then read the one topic page your task needs from that version's folder.

---

## 📊 Feature Support Matrix

| Feature | v1.10 | v1.11 | v1.12 | v1.13 | v1.14 | v1.15 | v1.16 | v1.17 | v1.18 | v1.19 | v1.20 | Reference |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| Pregel/BSP workflow execution, executors, edges, streaming | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `SKILL.md` |
| `RequestPort` HITL and `RunStatus.PendingRequests` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/hitl-and-routing.md` |
| Scoped workflow state and checkpointing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/state-and-persistence.md` |
| Sequential / concurrent / group-chat / handoff orchestration builders | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/orchestration-patterns.md` |
| Context compaction: strategies, triggers, `CompactionProvider` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/context-compaction.md` |
| Workflow event taxonomy (21 types) and typed output | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/workflow-events.md` |
| Declarative executors: `[MessageHandler]` + `ConfigureProtocol` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/declarative-executors.md` |
| Hosting a workflow as an `AIAgent` (`WorkflowHostingExtensions.AsAIAgent`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.20/workflow-hosting.md` (v1.19: `v1.19/workflow-hosting.md`; earlier: `vX.X/state-and-persistence.md`) |
| `LoopAgent` and loop evaluators | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-loops.md` |
| Context-aware agent skills and tool auto-approval | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-skills.md` |
| Composable/disposable skill sources and renamed `AgentFileStore` contract | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `vX.X/agent-skills.md` |
| Contextual `ToolAutoApprovalRuleContext` rules | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-skills.md` |
| Async agent-mode state and async message injection | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-layer-core.md` |
| Approval-response binding and approval-not-required bypass middleware | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.14/agent-layer-core.md` |
| `CheckpointManager.GetLatestCheckpointAsync` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.15/state-and-persistence.md` |
| `WatchStreamAsync(blockOnPendingRequest, …)` overload | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | `v1.15/production-readiness.md` |
| Magentic prompt overrides + response language (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | ⚗️ | ⚗️ | ⚗️ | `v1.20/hitl-and-routing.md` (v1.19: `v1.19/hitl-and-routing.md`; earlier: `v1.16/hitl-and-routing.md`) |
| `ChatClientAgentOptions.AllowConcurrentInvocation` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | `v1.20/agent-middleware.md` (v1.19: `v1.19/agent-middleware.md`; earlier: `v1.18/agent-layer-core.md`) |
| `ToolApprovalAgentOptions.MaxAutoApprovalIterations` (default 40) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | `v1.20/agent-skills.md` (v1.19: `v1.19/agent-skills.md`; earlier: `v1.18/agent-skills.md`) |
| Invocable-function bypass: `EnableInvocableFunctionBypassing` / `UseInvocableFunctionBypassing` (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | ⚗️ | `v1.20/agent-middleware.md` (v1.19: `v1.19/agent-middleware.md`; v1.18: `v1.18/agent-layer-core.md`) |
| `BackgroundAgentsProvider.ReleaseSessionAsync` (⚗️ the type is `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | ⚗️ | `v1.20/background-agents.md` (v1.19: `v1.19/agent-middleware.md`; v1.18: `v1.18/agent-layer-core.md`) |
| `BackgroundAgentsProviderOptions.WaitTimeout` — wait-tool timeout, default 5 min (⚗️ the type is `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | `v1.20/background-agents.md` |
| `RoutePersistingRoutingChatClient` session-persisted routing (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | `v1.20/agent-middleware.md` (v1.19: `v1.19/agent-middleware.md`) |
| `WorkflowAgentMetadata` + `WorkflowHostingExtensions.WithCheckpointing` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | `v1.20/workflow-hosting.md` (v1.19: `v1.19/workflow-hosting.md`) |
| `WorkflowSessionCheckpointRecovery` (⚗️ `MAAI001`) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | `v1.20/workflow-hosting.md` (v1.19: `v1.19/workflow-hosting.md`) |
| `FeatureUsage` process-wide feature tracking (⚗️ `MAAI001`, infrastructure) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚗️ | ⚗️ | `v1.20/agent-middleware.md` (v1.19: `v1.19/agent-middleware.md`) |
| `AgentSkillsSource.GetSkillsAsync(ct)` bare-token overload + `UseScriptApproval` | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | **Removed in v1.12** — migration: `v1.12/agent-skills.md` |
| Pre-1.13 `AgentFileStore` file methods (`WriteFileAsync`/`ReadFileAsync`/`ListFilesAsync`/`SearchFilesAsync`; `ListDirectoriesAsync` from v1.11) | ✅ | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | **Renamed in v1.13** — migration: `v1.13/agent-skills.md` |
| `WorkflowSuspendedException` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **Never shipped in any release — see warning below** |

⚗️ = ships, but gated behind the `MAAI001` experimental diagnostic (a compile **error** until suppressed).
⛔ = existed in an earlier release and was **removed or renamed** — code written against it will not compile. ❌ = never present in that version.

## 🔑 Release deltas, one line each

The **adoption traps** for each release — what breaks when you take the new API up — live in that release's own topic pages; the Reference column above points at them. Only the removal/rename table below stays here.

| From → to | What moved | Breaking? |
| --- | --- | :---: |
| v1.10 → v1.11 | the autonomous loop-agent family | no |
| v1.11 → v1.12 | context-aware skill sources, caching, tool auto-approval | **yes** |
| v1.12 → v1.13 | composable/disposable skill sources | **yes** |
| v1.13 → v1.14 | async agent modes and message injection, contextual auto-approval, approval middleware | **yes** |
| v1.14 → v1.15 | Workflows only: latest-checkpoint lookup, pending-request streaming overload | no |
| v1.15 → v1.16 | Workflows only: Magentic prompt customization, all `MAAI001` | no |
| v1.16 → v1.17 | **nothing at all** — all three assemblies byte-identical by mechanical diff | no |
| v1.17 → v1.18 | agent layer only: concurrent invocation, auto-approval cap, bypass, background release; half `MAAI001` | no |
| v1.18 → v1.19 | `FeatureUsage`, session-persisting routing client, hosted-workflow checkpoint controls; `Microsoft.Extensions.AI` 10.7.0 → **10.9.0** | no |
| v1.19 → v1.20 | agent layer only: **one property**, `BackgroundAgentsProviderOptions.WaitTimeout`; Workflows and Abstractions byte-identical; `Microsoft.Extensions.AI` stays 10.9.0 | no |

"Breaking" means something was removed or renamed — those rows are the ⛔ cells above and the table below.

## 🔀 Migration traps: APIs that were removed or renamed

These name shapes that **no longer exist in any current surface**, so they live here rather than in a version folder — this is the one document checked against every version's dump. Adoption traps for APIs that *do* exist live in the topic pages of the versions they concern.

| v1.13 shape | v1.14 replacement |
| --- | --- |
| `AgentModeProviderOptions.AgentMode(name, description)` and `.Description` | `AgentModeProviderOptions.AgentMode(name, instructions)` and `.Instructions` |
| `AgentModeProvider.GetMode` / `SetMode` | `GetModeAsync` / `SetModeAsync` with a cancellation token |
| Auto-approval rule receives `FunctionCallContent` | Rule receives `ToolAutoApprovalRuleContext`; use `.FunctionCallContent` for the call |
| `MessageInjectingChatClient.EnqueueMessages` / `GetPendingMessages` | `EnqueueMessagesAsync` / `GetPendingMessagesAsync` with a cancellation token |
| `EnableNonApprovalRequiredFunctionBypassing` | `DisableApprovalNotRequiredFunctionBypassing` |
| `UseNonApprovalRequiredFunctionBypassing` | `UseApprovalNotRequiredFunctionBypassing` — the `ILoggerFactory` parameter is **optional** (default `null`); the surface dump renders it as required |
| No approval-response binding switch | `DisableApprovalResponseBinding` and `UseApprovalResponseBinding` |

The v1.12 and v1.13 removals are in the matrix above (⛔ rows), with their migration pages named there.

---

> [!WARNING]
> **`WorkflowSuspendedException` does not exist in any MAF version** (verified against the v1.10.0 through v1.20.0 DLL surfaces). Some pre-release documentation and LLM training data describe a suspend-by-exception HITL pattern with an `InProcessExecution.ResumeAsync(workflow, runId)` shape — that API surface was never shipped. Human-in-the-loop is modeled with `RequestPort` + `RunStatus.PendingRequests` + `Run.ResumeAsync(responses)` in **all** supported versions. If you find yourself writing `throw new WorkflowSuspendedException(...)`, stop — it will not compile.

---

## 📂 Target Version References

Each folder holds one page per topic, self-contained for that version. Read the page your task needs, not the folder.

| Folder | Pinned projects on |
| --- | --- |
| [v1.11](v1.11/) | 1.11.x — and 1.10.x, with the fallback rules below |
| [v1.12](v1.12/) | 1.12.x — context-aware agent skills |
| [v1.13](v1.13/) | 1.13.x — composable/disposable skills, renamed `AgentFileStore` |
| [v1.14](v1.14/) | 1.14.x — async agent modes, contextual auto-approval, approval middleware |
| [v1.15](v1.15/) | 1.15.x — latest-checkpoint resolution, pending-request streaming overload |
| [v1.16](v1.16/) | 1.16.x — Magentic prompt overrides (experimental) |
| [v1.17](v1.17/) | 1.17.x — API-identical to v1.16; the folder confirms there is nothing to migrate |
| [v1.18](v1.18/) | 1.18.x — concurrent invocation, auto-approval cap, bypass, background release |
| [v1.19](v1.19/) | 1.19.x — session-persisted routing, hosted-workflow checkpoint controls |
| [v1.20](v1.20/) | **latest verified** — API-identical to v1.19 except the background wait-tool timeout; background agents get their own page |

**v1.11–v1.19 are frozen as historical record.** They are correct for their pin and are not restructured further; new topics are documented in the current folder, with the matrix row naming it.

---

## ⚠️ Version Fallback & Future Rules

- **v1.10.x projects:** use the v1.11 folder for workflow guidance, but do not use the loop-agent family or the `WithChainOnlyAgentResponses` sequential chain-only option (neither exists in 1.10).
- **Versions newer than v1.20:** treat every signature as unverified until a new surface dump and compile test exist. Regenerate ground truth via the private analyzer (`--version <ver>`) before relying on new APIs.
- Do not mix newer features (composable skill sources, loop evaluators, context-aware skills, async agent modes, the v1.15 Workflows additions, Magentic prompt overrides, the v1.18 agent options, the v1.19 routing client and hosted-workflow checkpoint controls, the v1.20 wait-tool timeout) into older-pinned codebases.
- **Experimental APIs are not a version feature you can rely on.** Anything behind `MAAI001` may change or vanish in a later minor release; isolate it behind your own seam. The gate is applied per member, not per release: a version's additions can be half gated and half not (v1.18 and v1.19 both are; v1.20's single addition is gated).

---
*Verified against MAF v1.10.0 / v1.11.0 / v1.12.0 / v1.13.0 / v1.14.0 / v1.15.0 / v1.16.0 / v1.17.0 / v1.18.0 / v1.19.0 / v1.20.0 DLL surfaces and compile tests (2026-09-03). The v1.20 column was added on 2026-09-03 from the mechanical 1.19.0 → 1.20.0 surface diff (one added member, no removals). The per-release adoption traps this file used to carry were relocated on 2026-09-01 into the topic pages of the versions they concern, unchanged in substance.*
