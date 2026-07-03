# 🧩 Agent Skills Sources & Provider (v1.11 — legacy shapes)

The agent-skills system feeds reusable skill definitions (`AgentSkill`) into an agent's context via `AgentSkillsProvider` (an `AIContextProvider`). This page documents the **v1.11 shapes; several were removed in v1.12** — see the breaking-change box below before writing new code.

> [!WARNING]
> This entire API family is marked **experimental** — compiling against it raises diagnostic **`MAAI001`**. Suppress it deliberately: `<NoWarn>$(NoWarn);MAAI001</NoWarn>` or `#pragma warning disable MAAI001`.

---

## 🏛️ Core Types

* **`AgentSkill`** (abstract) — `AgentSkillFrontmatter Frontmatter { get; }`; `GetContentAsync(ct)`, `GetResourceAsync(name, ct)`, `GetScriptAsync(name, ct)`. Skill metadata lives on the frontmatter: `Name`, `Description`, `License`, `Compatibility`, `AllowedTools`, `Metadata`. (There is no `Name` directly on `AgentSkill` — go through `Frontmatter`.)
* **`AgentSkillsSource`** (abstract) — v1.11 shape: `abstract Task<IList<AgentSkill>> GetSkillsAsync(CancellationToken cancellationToken)`.
* **`AgentSkillsProviderBuilder`** — `UseFileSkill(s)`, `UseSkill(s)`, `UseSource(AgentSkillsSource)`, `UsePromptTemplate`, `UseScriptApproval(bool)`, `UseFileScriptRunner`, `UseLoggerFactory`, `UseFilter(Func<AgentSkill, bool>)`, `UseOptions(Action<AgentSkillsProviderOptions>)`, `Build()`.
* **`AgentSkillsProviderOptions`** — includes `bool ScriptApproval { get; set; }` and `bool DisableCaching { get; set; }`.

## 🛠️ Compile-Verified Example

```csharp
using Microsoft.Agents.AI;

public sealed class DbSkillsSource : AgentSkillsSource
{
    public override Task<IList<AgentSkill>> GetSkillsAsync(CancellationToken ct)
        => LoadSkillsFromDatabaseAsync(ct);
}

var provider = new AgentSkillsProviderBuilder()
    .UseSource(new DbSkillsSource())
    .UseFilter((AgentSkill s) => s.Frontmatter.Name != "dangerous")
    .UseScriptApproval(true)
    .UseOptions(o => { o.ScriptApproval = true; o.DisableCaching = true; })
    .Build();
```

> [!CAUTION]
> **Removed in v1.12** (all three verified by compile test against 1.12.0):
> * `GetSkillsAsync(CancellationToken)` override → fails with CS0115; v1.12 requires `GetSkillsAsync(AgentSkillsSourceContext, CancellationToken)`. <!-- v1.12 -->
> * `UseFilter(Func<AgentSkill, bool>)` → the predicate is now `Func<AgentSkill, AgentSkillsSourceContext, bool>` (CS1593 on 1-arg lambdas). <!-- v1.12 -->
> * `UseScriptApproval(bool)` and the `ScriptApproval` / `DisableCaching` bool options → gone (CS0117); replaced by `DisableCaching()` / `UseCachingOptions(...)` on the builder. <!-- v1.12 -->
>
> Migration guide: [v1.12 agent-skills.md](../v1.12/agent-skills.md).

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03). All code samples compile-tested against the pinned 1.11.0 packages.*
