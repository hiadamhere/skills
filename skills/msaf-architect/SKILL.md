---
name: msaf-architect
description: C# architecture and version-specific API guidance for Microsoft Agent Framework (MAF/MSAF) agent workflows. Use when building or debugging multi-agent workflows with the Microsoft.Agents.AI / Microsoft.Agents.AI.Workflows NuGet packages in .NET — executors, edges, checkpointing, human-in-the-loop. Always resolve the installed package version first and load the matching references/vX.X folder. Not for the Microsoft 365 Agents SDK (Microsoft.Agents.Builder).
---

# 🏛️ Microsoft Agent Framework (MAF) C# Architect Skill

This skill embeds the architectural guidelines, design principles, and API mappings for building multi-agent systems using the Microsoft Agent Framework (MAF).

---

## 🧭 Getting Started: Version Resolution

The Workflows layer is API-stable across v1.10–v1.12, but the agent layer (`Microsoft.Agents.AI`) changes between releases — and stale tutorials/model memory describe APIs that were **never shipped** (e.g. `WorkflowSuspendedException`). **Resolve the version, then trust only the matching reference folder and the version map.**

1. Check the local project's `.csproj` or dependency files to resolve the installed version of `Microsoft.Agents.AI.Workflows` or `Microsoft.Agents.AI`.
   * *Note:* If the project references `Microsoft.Agents.Builder` or `Microsoft.Agents.Hosting.AspNetCore` (v1.6.x), that belongs to the separate **Microsoft 365 Agents SDK**—this skill does not apply to that SDK.
2. Consult the **[Version Compatibility Matrix](references/version-map.md)** to see feature availability.
3. Load the matching reference folder:
   * **[v1.11 Reference Guides](references/v1.11/)**
   * **[v1.12 Reference Guides (Latest)](references/v1.12/)**

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
