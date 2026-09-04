---
name: msaf-architect
description: C# architecture and version-specific API guidance for Microsoft Agent Framework (MAF/MSAF) agent workflows. Use when building or debugging multi-agent workflows with the Microsoft.Agents.AI / Microsoft.Agents.AI.Workflows NuGet packages in .NET — executors, edges, checkpointing, human-in-the-loop, and the four orchestration builders (sequential, concurrent, group chat, handoff), plus the agent layer (ChatClientAgent options, tool approval, per-session chat-client routing, background agents). Always resolve the installed package version first, then load the matching `references/vX.X/<topic>.md` page for the task in hand. Not for the Microsoft 365 Agents SDK (Microsoft.Agents.Builder).
---

# 🏛️ Microsoft Agent Framework (MAF) C# Architect Skill

This skill embeds the architectural guidelines, design principles, and API mappings for building multi-agent systems using the Microsoft Agent Framework (MAF).

---

## 🧭 Getting Started: Version Resolution

The Workflows layer was API-stable across v1.10–v1.14, adds members in v1.15, v1.16 and v1.19, and is unchanged in v1.17, v1.18 and v1.20; the agent layer (`Microsoft.Agents.AI`) changes between the earlier releases, adds again in v1.18 and v1.19, and adds a single property in v1.20 — and stale tutorials/model memory describe APIs that were **never shipped** (e.g. `WorkflowSuspendedException`). **Resolve the version, then trust only the matching reference page and the version map.**

1. **Resolve the version.** Read the project's `.csproj` or dependency files for the installed `Microsoft.Agents.AI.Workflows` / `Microsoft.Agents.AI` version.
   * *Note:* a project referencing `Microsoft.Agents.Builder` or `Microsoft.Agents.Hosting.AspNetCore` (v1.6.x) belongs to the separate **Microsoft 365 Agents SDK** — this skill does not apply to it.
2. **Check feature availability** in the **[Version Compatibility Matrix](references/version-map.md)**: which versions have the feature, and which cells are `MAAI001`-gated.
3. **Read the one page your task needs**, from the folder matching the resolved version.

| Your task | Page |
| --- | --- |
| Build an agent: `ChatClientAgent` construction, sessions, workflow binding, modes | [`agent-layer-core.md`](references/v1.20/agent-layer-core.md) |
| Wrap an agent: approval middleware, concurrent invocation, per-session routing | [`agent-middleware.md`](references/v1.20/agent-middleware.md) **(v1.19+)** |
| Background agents: releasing a session, the wait-tool timeout | [`background-agents.md`](references/v1.20/background-agents.md) **(v1.20+)** |
| Autonomous iteration: `LoopAgent` and loop evaluators | [`agent-loops.md`](references/v1.20/agent-loops.md) |
| Agent skills, tool approval, file stores | [`agent-skills.md`](references/v1.20/agent-skills.md) |
| Keep a long conversation inside the window | [`context-compaction.md`](references/v1.20/context-compaction.md) |
| Write an executor: message handlers, protocol configuration | [`declarative-executors.md`](references/v1.20/declarative-executors.md) |
| Human-in-the-loop, request ports, Magentic manager-led planning | [`hitl-and-routing.md`](references/v1.20/hitl-and-routing.md) |
| Choose an orchestration: sequential, concurrent, group chat, handoff | [`orchestration-patterns.md`](references/v1.20/orchestration-patterns.md) |
| Ship it: streaming, observability, error handling, cancellation | [`production-readiness.md`](references/v1.20/production-readiness.md) |
| Workflow state, scopes, checkpoint stores | [`state-and-persistence.md`](references/v1.20/state-and-persistence.md) |
| Host a workflow as an agent: `AsAIAgent`, checkpoint redirection, run recovery | [`workflow-hosting.md`](references/v1.20/workflow-hosting.md) **(v1.19+)** |
| Observe a run: the event taxonomy and typed output | [`workflow-events.md`](references/v1.20/workflow-events.md) |

> [!IMPORTANT]
> **Read the single page your task needs, not the folder.** The links above resolve to `v1.20`, the newest verified version; on any other pin, substitute your version folder in the path (`references/v1.16/hitl-and-routing.md`). **The rows marked with a version are the exception** — those pages exist from that version on: the two **(v1.19+)** pages have their material in `agent-layer-core.md` and `state-and-persistence.md` on v1.11–v1.18, and the **(v1.20+)** page's release material is in `agent-middleware.md` on v1.19 and in `agent-layer-core.md` on v1.18 (the wait timeout itself exists only from v1.20; before v1.18 there is no release API). Pages from v1.19 on are self-contained: it does not require reading a second page to be understood, and any link it carries to another version's folder is labelled historical context. Older folders are frozen per-release deltas and may still chain. Loading a whole folder buys you every other topic in it.

---

## ⛔ Rules that outrank any example you have seen

* **`WorkflowSuspendedException` does not exist in any MAF version.** Human-in-the-loop is `RequestPort` + `RunStatus.PendingRequests` + `Run.ResumeAsync(responses)` in every supported release. If you are writing `throw new WorkflowSuspendedException(...)`, stop — it will not compile.
* **Anything behind `MAAI001` is a compile *error* until suppressed**, and the gate is applied **per member**, not per release: a version's additions can be half gated and half not (v1.18 and v1.19 both are; v1.20's single addition is gated). The version map's ⚗️ cells name exactly which members. Suppress with `<NoWarn>$(NoWarn);MAAI001</NoWarn>`, scoped to the project that needs it.
* **`ReflectingExecutor<T>` is `[Obsolete]`** in every documented version.
* **`WorkflowOutputEvent` must be the last `case`** when switching over the event stream — earlier cases would shadow it.
* **`AsAIAgent` throws on the first run** unless the workflow's start executor speaks the chat protocol (`List<ChatMessage>` + `TurnToken`); a hosted agent given no explicit `id` gets a fresh identifier on every call.
* **Two hosted-workflow failures are silent, not loud.** `WithCheckpointing` returns the agent **unchanged** when it is behind a wrapper or already has a manager, and `WorkflowSessionCheckpointRecovery.TryPrepare` accepts a checkpoint id that does not exist — the `KeyNotFoundException` arrives on the next run. Assert, do not assume.
* **Use the shipped compaction layer** for history growth, never hand-rolled trimming.
* **Versions newer than the newest reference folder are unverified.** Treat every signature as unproven until a surface dump and compile test exist for it.

---

## 🧩 Core Architectural Blueprint (All Versions)

MAF orchestrates multi-agent systems as a directed graph where processing nodes (**Executors**) communicate over directed paths (**Edges**). The engine processes messages using a **Bulk-Synchronous-Parallel (Pregel-style) execution model** structured in discrete **supersteps**:

1. **Superstep Initialization:** Collects all pending messages in queues.
2. **Execution Barrier:** Runs all targeted executors concurrently.
3. **Synchronization Barrier:** Waits for all active executors in the superstep to complete before advancing.

> [!IMPORTANT]
> Because of this execution model, parallel paths of unequal length are gated at each superstep. Keep sequential execution chains consolidated when parallel processes must run with maximum independent throughput.

---

## 🚫 Anti-Patterns to Avoid

* **Cross-Superstep Parallelism Assumptions:** Do not assume a parallel branch can run infinitely ahead of a sibling branch; both branches are synchronized at the end of every step.
* **Direct Task.Run in Executors:** Avoid spawning unmanaged parallel tasks inside `HandleAsync`. Rely instead on the builder's fan-out capabilities to maintain telemetry context and state synchronization.
* **Type-Incompatible Edges:** Do not connect an executor outputting `TypeA` to an executor expecting `TypeB` without an intermediate mapping executor, or `builder.Build()` will throw.
