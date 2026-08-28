# 🗜️ Context Compaction (v1.12)

The `Microsoft.Agents.AI.Compaction` namespace is **byte-identical to v1.11** by mechanical surface diff — all 15 types, unchanged from v1.10 through v1.19.

Use [the v1.11 compaction guide](../v1.11/context-compaction.md) as written: strategies decide *what* to drop or summarise, `CompactionTrigger`s decide *when*, and `CompactionProvider` plugs the pair into an agent so it happens without a run loop of your own.

The v1.11 guide's traps are unchanged in v1.12:

<!-- shared:compaction-traps -->
- **`ToolResultCompactionStrategy.ToolCallFormatter` is `init`-only** despite reflecting as `{ get; set; }` — assign it in an object initializer or hit **CS8852**.
- **`CompactAsync` is not the override target.** It is public but not `virtual` (**CS0506**); the abstract member is `protected CompactCoreAsync`, which the surface dump never shows. The base constructor is `protected` and requires a trigger (**CS7036**).
- **`AIAgentBuilder.UseAIContextProviders` rejects a `CompactionProvider`** (**CS1503**) — its parameter is `MessageAIContextProvider[]`. Use `ChatClientBuilder.UseAIContextProviders`, or `ChatClientAgentOptions.AIContextProviders`.
<!-- /shared:compaction-traps -->

For single-agent iteration see [Agent Loops](agent-loops.md); for the orchestration builders see [Orchestration Patterns](orchestration-patterns.md).

---
*Verified against MAF v1.12.0 DLL surface (2026-08-12). The compaction namespace is byte-identical across v1.10–v1.19 by mechanical diff (range extended to v1.19 on 2026-08-27); the probe program behind the v1.11 guide compiles unmodified against pinned 1.11.0, 1.14.0 and 1.17.0.*
