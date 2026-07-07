# 🧩 Agent Skills Sources & Provider (v1.12 — context-aware)

The agent-skills system feeds reusable skill definitions (`AgentSkill`) into an agent's context via `AgentSkillsProvider` (an `AIContextProvider`). v1.12 made this system **context-aware**: sources and filters now receive an `AgentSkillsSourceContext` identifying the requesting agent and session — a **breaking change** from v1.11.

> [!WARNING]
> This entire API family is marked **experimental** — compiling against it raises diagnostic **`MAAI001`**. Suppress it deliberately: `<NoWarn>$(NoWarn);MAAI001</NoWarn>` or `#pragma warning disable MAAI001`.

---

## 🏛️ Core Types (v1.12 shapes)

* **`AgentSkillsSourceContext`** — `AgentSkillsSourceContext(AIAgent agent, AgentSession session)`; exposes `AIAgent Agent { get; }` and `AgentSession Session { get; }`.
* **`AgentSkillsSource`** (abstract) — `abstract Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken cancellationToken)`.
* **`AgentFileSkillsSource`** *(new)* — file-based source: `(string skillPath | IEnumerable<string> skillPaths, AgentFileSkillScriptRunner scriptRunner, AgentFileSkillsSourceOptions options, ILoggerFactory loggerFactory)`.
* **`AgentSkillsProviderBuilder`** — context-aware `UseFilter(Func<AgentSkill, AgentSkillsSourceContext, bool>)`, factory `UseSource(Func<ILoggerFactory, AgentSkillsSource>)`, `DisableCaching()`, `UseCachingOptions(Action<CachingAgentSkillsSourceOptions>)`, plus the carried-over `UseFileSkill(s)`, `UseSkill(s)`, `UsePromptTemplate`, `UseFileScriptRunner`, `UseLoggerFactory`, `UseOptions`, `Build()`.
* **`CachingAgentSkillsSourceOptions`** — `Func<AgentSkillsSourceContext, string> CacheIsolationKeySelector { get; set; }` (partition the skills cache per agent/session).
* **`AgentSkillsProviderOptions`** — gains `bool IncludeDetailedErrors { get; set; }`.

## 🔐 Tool Auto-Approval Rules *(new in v1.12)*

Pre-approve tool calls without human confirmation using built-in rules of type `Func<FunctionCallContent, ValueTask<bool>>`:

* `AgentSkillsProvider.AllToolsAutoApprovalRule` / `AgentSkillsProvider.ReadOnlyToolsAutoApprovalRule`
* `FileAccessProvider.AllToolsAutoApprovalRule` / `FileAccessProvider.ReadOnlyToolsAutoApprovalRule`
* `ToolApprovalAgent.AllToolsAutoApprovalRule`

Wire them via `ToolApprovalAgentOptions.AutoApprovalRules` (an `IEnumerable` of such rules).

## 🛠️ Compile-Verified Example

```csharp
using Microsoft.Agents.AI;

public sealed class DbSkillsSource : AgentSkillsSource
{
    public override Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken ct)
        => LoadSkillsForAgentAsync(context.Agent.Id, ct);
}

var provider = new AgentSkillsProviderBuilder()
    .UseSource(lf => new DbSkillsSource())
    .UseFilter((AgentSkill s, AgentSkillsSourceContext ctx) => s.Frontmatter.Name != "dangerous")
    .UseCachingOptions(c => c.CacheIsolationKeySelector = ctx => ctx.Agent.Id)
    .UseOptions(o => o.IncludeDetailedErrors = true)
    .Build();

var approvalAgent = new ToolApprovalAgent(innerAgent, new ToolApprovalAgentOptions
{
    AutoApprovalRules = new[] { AgentSkillsProvider.ReadOnlyToolsAutoApprovalRule }
});
```

## ⬆️ Migration from v1.11 (compile-verified breaking changes)

| v1.11 (legacy) | v1.12 (replacement) | Error if unmigrated |
|---|---|---|
| `GetSkillsAsync(CancellationToken)` override | `GetSkillsAsync(AgentSkillsSourceContext, CancellationToken)` | CS0115 / CS0534 |
| `UseFilter(Func<AgentSkill, bool>)` | `UseFilter(Func<AgentSkill, AgentSkillsSourceContext, bool>)` | CS1593 |
| `UseScriptApproval(bool)`; `ScriptApproval` / `DisableCaching` bool options | `DisableCaching()` / `UseCachingOptions(...)` on the builder | CS0117 | <!-- v1.11 -->

---
*Verified against MAF v1.12.0 DLL surface (2026-07-03). All code samples compile-tested against the pinned 1.12.0 packages, and every legacy shape's removal verified by negative compile test.*
