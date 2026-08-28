---
name: msaf-architect
description: C# architecture and version-specific API guidance for Microsoft Agent Framework (MAF/MSAF) agent workflows. Use when building or debugging multi-agent workflows with the Microsoft.Agents.AI / Microsoft.Agents.AI.Workflows NuGet packages in .NET — executors, edges, checkpointing, human-in-the-loop, and the four orchestration builders (sequential, concurrent, group chat, handoff), plus the agent layer (ChatClientAgent options, tool approval, per-session chat-client routing). Always resolve the installed package version first and load the matching references/vX.X folder. Not for the Microsoft 365 Agents SDK (Microsoft.Agents.Builder).
---

# 🏛️ Microsoft Agent Framework (MAF) C# Architect Skill

This skill embeds the architectural guidelines, design principles, and API mappings for building multi-agent systems using the Microsoft Agent Framework (MAF).

---

## 🧭 Getting Started: Version Resolution

The Workflows layer was API-stable across v1.10–v1.14, adds members in v1.15, v1.16 and v1.19, and is unchanged in v1.17 and v1.18; the agent layer (`Microsoft.Agents.AI`) changes between the earlier releases and adds again in v1.18 and v1.19 — and stale tutorials/model memory describe APIs that were **never shipped** (e.g. `WorkflowSuspendedException`). **Resolve the version, then trust only the matching reference folder and the version map.**

1. Check the local project's `.csproj` or dependency files to resolve the installed version of `Microsoft.Agents.AI.Workflows` or `Microsoft.Agents.AI`.
   * *Note:* If the project references `Microsoft.Agents.Builder` or `Microsoft.Agents.Hosting.AspNetCore` (v1.6.x), that belongs to the separate **Microsoft 365 Agents SDK**—this skill does not apply to that SDK.
2. Consult the **[Version Compatibility Matrix](references/version-map.md)** to see feature availability.
   * Writing an executor that handles several message types: **[Declarative Executors](references/v1.11/declarative-executors.md)** — and note `ReflectingExecutor<T>` is `[Obsolete]` in every documented version.
   * Observing a run: the 21-type event stream is mapped in **[Workflow Events](references/v1.11/workflow-events.md)** (identical v1.11–v1.19) — including why `WorkflowOutputEvent` must be the last `case` in a `switch`.
   * Long-running agents: history growth is handled by the shipped compaction layer — see **[Context Compaction](references/v1.11/context-compaction.md)** (unchanged v1.10–v1.19), not by hand-rolled trimming.
   * Hosting a workflow as an agent: every version's `state-and-persistence.md` carries the rule — `AsAIAgent` throws on first run unless the workflow speaks the chat protocol, and an agent without an explicit `id` gets a fresh one per call. Continuing a hosted run from a checkpoint is v1.19: **[State and Persistence (v1.19)](references/v1.19/state-and-persistence.md)** — `WithCheckpointing` silently returns a wrapped agent unchanged, and `WorkflowSessionCheckpointRecovery.TryPrepare` does not check that the id exists.
   * Anything behind **`MAAI001`** is a compile *error* until suppressed, and the gate is per member: the version map's ⚗️ cells list exactly which v1.16, v1.18 and v1.19 members are gated and which siblings are not.
3. Load the matching reference folder:
   * **[v1.11 Reference Guides](references/v1.11/)**
   * **[v1.12 Reference Guides](references/v1.12/)**
   * **[v1.13 Reference Guides](references/v1.13/)** — composable/disposable agent skills + renamed `AgentFileStore` contract
   * **[v1.14 Reference Guides](references/v1.14/)** — async agent modes, contextual tool auto-approval, async message injection, and approval middleware changes
   * **[v1.15 Reference Guides](references/v1.15/)** — latest-checkpoint resolution + the `blockOnPendingRequest` streaming overload
   * **[v1.16 Reference Guides](references/v1.16/)** — Magentic manager prompt overrides and response language (experimental, `MAAI001`)
   * **[v1.17 Reference Guides](references/v1.17/)** — API-identical to v1.16; nothing to migrate
   * **[v1.18 Reference Guides](references/v1.18/)** — concurrent tool invocation, the auto-approval iteration cap (default 40), the invocable-function bypass (experimental, `MAAI001`; in a custom pipeline it sits *below* approval-response binding or its stored calls are silently dropped), background-session release
   * **[v1.19 Reference Guides (Latest)](references/v1.19/)** — session-persisted chat-client routing (experimental, `MAAI001`), hosted-workflow checkpoint controls (`WithCheckpointing`, `WorkflowAgentMetadata`, experimental `WorkflowSessionCheckpointRecovery`), `Microsoft.Extensions.AI` 10.9.0

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
