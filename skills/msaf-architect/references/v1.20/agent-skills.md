# 🧰 Agent Skills, Files, and Tool Approval (v1.20)

The agent-skills system feeds reusable skill definitions (`AgentSkill`) into an agent's context through `AgentSkillsProvider`, an `AIContextProvider`. Sources and filters are **context-aware** — they receive an `AgentSkillsSourceContext` identifying the requesting agent and session. The surface is byte-identical from v1.18 through v1.20 by mechanical diff.

> [!WARNING]
> This entire API family is marked **experimental** — compiling against it raises diagnostic **`MAAI001`**. Suppress it deliberately: `<NoWarn>$(NoWarn);MAAI001</NoWarn>` or `#pragma warning disable MAAI001`. The auto-approval iteration cap below is **not** gated.

---

## 🏛️ Core types

* **`AgentSkillsSourceContext`** — `AgentSkillsSourceContext(AIAgent agent, AgentSession session)`; exposes `AIAgent Agent { get; }` and `AgentSession Session { get; }`.
* **`AgentSkillsSource`** (abstract, `IDisposable`) — override `Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken cancellationToken)`; override the virtual `Dispose()` to release handles.
* **`AgentSkillsProvider`** (`IDisposable`) — the source-based constructor takes an `ownsSource` flag: `AgentSkillsProvider(AgentSkillsSource source, AgentSkillsProviderOptions options, ILoggerFactory loggerFactory, bool ownsSource)`. The `skillPath(s)`, `AgentSkill[]`, and `IEnumerable<AgentSkill>` constructors take no such flag.
* **`AgentSkillsProviderBuilder`** — context-aware `UseFilter(Func<AgentSkill, AgentSkillsSourceContext, bool>)`, factory `UseSource(Func<ILoggerFactory, AgentSkillsSource>)`, `DisableCaching()`, `UseCachingOptions(Action<CachingAgentSkillsSourceOptions>)`, plus `UseFileSkill(s)`, `UseSkill(s)`, `UsePromptTemplate`, `UseFileScriptRunner`, `UseLoggerFactory`, `UseOptions`, `Build()`.
* **`AgentFileSkillsSource`** — file-based source: `(string skillPath | IEnumerable<string> skillPaths, AgentFileSkillScriptRunner scriptRunner, AgentFileSkillsSourceOptions options, ILoggerFactory loggerFactory)`.
* **`CachingAgentSkillsSourceOptions`** — `Func<AgentSkillsSourceContext, string> CacheIsolationKeySelector` (partition the cache per agent/session) and `Nullable<TimeSpan> RefreshInterval` (re-pull skills after the interval elapses).
* **`AgentSkillsProviderOptions`** — `bool IncludeDetailedErrors`, `string SkillsInstructionPrompt`, and the granular approval flags `DisableLoadSkillApproval`, `DisableReadSkillResourceApproval`, `DisableRunSkillScriptApproval`.

## 🧬 Composable skill sources

`DelegatingAgentSkillsSource` is the abstract base that forwards to an inner source; the concrete decorators wrap any source, including your own:

| Decorator | Constructor | Purpose |
|---|---|---|
| `CachingAgentSkillsSource` | `(AgentSkillsSource innerSource, CachingAgentSkillsSourceOptions options)` | Cache skills, optionally per agent/session and with a `RefreshInterval`. |
| `DeduplicatingAgentSkillsSource` | `(AgentSkillsSource innerSource, ILoggerFactory loggerFactory)` | Drop duplicate skills. |
| `FilteringAgentSkillsSource` | `(AgentSkillsSource innerSource, Func<AgentSkill, AgentSkillsSourceContext, bool> predicate, ILoggerFactory loggerFactory)` | Keep only skills matching a context-aware predicate. |
| `AggregatingAgentSkillsSource` | `(IEnumerable<AgentSkillsSource> sources)` | Merge several sources into one. |
| `AgentInMemorySkillsSource` | `(IEnumerable<AgentSkill> skills)` | Serve a fixed in-memory skill list. |

The builder's `UseFilter` / `UseCachingOptions` wire the equivalent decorators for you; construct them directly when you need explicit ordering.

## ♻️ Lifecycle, disposal and composition

`AgentSkillsSource`, `AgentSkillsProvider`, and `FileAccessProvider` implement `IDisposable`. Wrap the provider in `using` and pass `ownsSource: true` so it disposes the (composed) source it wraps:

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

// A custom source. AgentSkillsSource is IDisposable -- override Dispose() to release handles.
public sealed class DbSkillsSource : AgentSkillsSource
{
    public override Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken ct)
        => LoadSkillsForAgentAsync(context.Agent.Id, ct);
}

// ... elsewhere:
ILoggerFactory lf = NullLoggerFactory.Instance;
AgentSkillsSource source = new DbSkillsSource();

// Compose decorators: filter -> dedupe -> cache.
AgentSkillsSource filtered = new FilteringAgentSkillsSource(
    source,
    (AgentSkill s, AgentSkillsSourceContext ctx) => s.Frontmatter.Name != "dangerous",
    lf);
AgentSkillsSource deduped = new DeduplicatingAgentSkillsSource(filtered, lf);
AgentSkillsSource cached = new CachingAgentSkillsSource(deduped, new CachingAgentSkillsSourceOptions
{
    RefreshInterval = TimeSpan.FromMinutes(5),
    CacheIsolationKeySelector = ctx => ctx.Agent.Id,
});

// Provider is IDisposable; ownsSource:true disposes 'cached' when the provider is disposed.
using var provider = new AgentSkillsProvider(
    cached,
    new AgentSkillsProviderOptions
    {
        IncludeDetailedErrors = true,
        // Demo only. Each Disable* flag suppresses the HUMAN approval prompt for a whole
        // class of operations -- it fails open and silently. Default them off in production.
        DisableLoadSkillApproval = true,
        DisableRunSkillScriptApproval = false,
    },
    lf,
    ownsSource: true);
```

The fluent builder produces an equivalent (also disposable) provider:

```csharp
using var built = new AgentSkillsProviderBuilder()
    .UseSource(_ => new DbSkillsSource())
    .UseFilter((AgentSkill s, AgentSkillsSourceContext ctx) => true)
    .UseCachingOptions(c => c.RefreshInterval = TimeSpan.FromMinutes(1))
    .UseOptions(o => o.DisableRunSkillScriptApproval = true)   // demo only -- suppresses the human prompt
    .Build();
```

## 🗂️ The `AgentFileStore` contract

`AgentFileStore` — implemented by the built-in `FileSystemAgentFileStore` and `InMemoryAgentFileStore`, and consumed by `FileAccessProvider` — has no File infix on its methods, and directory listing is consolidated into one call:

```csharp
using Microsoft.Agents.AI;

AgentFileStore store = new InMemoryAgentFileStore();

await store.WriteAsync("notes/todo.txt", "buy milk", ct);
string text = await store.ReadAsync("notes/todo.txt", ct);
bool exists = await store.FileExistsAsync("notes/todo.txt", ct);

// ListChildrenAsync covers both files and directories.
IReadOnlyList<FileStoreEntry> children = await store.ListChildrenAsync("notes", ct);
foreach (FileStoreEntry entry in children)
    Console.WriteLine($"{entry.Name} ({entry.Type})");

IReadOnlyList<FileSearchResult> hits = await store.SearchAsync("notes", "milk", "*.txt", recursive: true, ct);

await store.DeleteAsync("notes/todo.txt", ct);
```

`ListChildrenAsync` returns `IReadOnlyList<FileStoreEntry>` — each entry carries `Name` and `Type` — rather than bare path strings. The `FileLineEdit` type (`LineNumber`, `NewLine`) is used by line-oriented file-edit tools.

> [!IMPORTANT]
> This contract was **renamed in v1.13** and the pre-1.13 method names no longer exist. If you are upgrading from 1.12 or earlier, the rename table and the earlier v1.11 → v1.12 context-awareness break are in [the version map](../version-map.md) and in the `v1.12` and `v1.13` folders — they name shapes that are absent from this version's surface, which is why they are not repeated here.

## 🔐 Approval control

Three mechanisms gate tool calls, and they compose.

**1. Auto-approval rules.** Every rule receives a `ToolAutoApprovalRuleContext` — the call plus the agent, session, request messages, and run options — so policy can consider more than the function name:

```csharp
using Microsoft.Agents.AI;

var options = new ToolApprovalAgentOptions
{
    AutoApprovalRules =
    [
        context => new ValueTask<bool>(
            context.FunctionCallContent.Name == "read_file" &&
            context.RequestMessages.Count > 0)
    ]
};
```

The built-in rules have the same contextual delegate shape and can be assigned directly: `AgentSkillsProvider.AllToolsAutoApprovalRule` / `.ReadOnlyToolsAutoApprovalRule`, `FileAccessProvider.AllToolsAutoApprovalRule` / `.ReadOnlyToolsAutoApprovalRule`, and `ToolApprovalAgent.AllToolsAutoApprovalRule`.

**2. Granular approval flags** suppress the approval prompt for whole operation classes:

* `AgentSkillsProviderOptions`: `DisableLoadSkillApproval`, `DisableReadSkillResourceApproval`, `DisableRunSkillScriptApproval`.
* `FileAccessProviderOptions`: `DisableWriteTools`, `DisableReadOnlyToolApproval`, `DisableWriteToolApproval`.

> [!WARNING]
> **Every `Disable*Approval` flag removes a human gate, and it fails open.** There is no prompt, and nothing in the transcript records that one was skipped. Set them only where the operation class is provably safe for the identity running it, and never together with a broad auto-approval rule — the two mechanisms compose, so the combination approves everything with no record.

**3. The auto-approval loop is bounded** (from v1.18):

```csharp
var gated = new ToolApprovalAgent(innerAgent, new ToolApprovalAgentOptions
{
    AutoApprovalRules = [ ToolApprovalAgent.AllToolsAutoApprovalRule ],
    MaxAutoApprovalIterations = 8,        // int?; null means ToolApprovalAgent.DefaultMaxAutoApprovalIterations (40)
});
```

- Each time every surfaced approval request is auto-approved, `ToolApprovalAgent` re-invokes the inner agent — a **fresh** call, so a per-request iteration cap inside the chat pipeline restarts every time and cannot bound the loop. A model that keeps requesting an auto-approved tool would otherwise drive an unbounded sequence of billable calls.
- `MaxAutoApprovalIterations` caps those re-invocations within a single run. On reaching it the agent makes **one final** inner invocation without auto-approving, so any remaining request is surfaced to the caller instead of approved silently.
- The default is `null`, which resolves to `ToolApprovalAgent.DefaultMaxAutoApprovalIterations` — a **`const int` of 40**. Being a constant it is invisible to a reflection dump, and assigning to it is **CS0131**.
- Raise the cap only when a longer auto-approval chain is the intended behavior; lower it for agents whose auto-approval rules are broad.

### Guidance

- Base policy on trusted identity and session state, not on model-supplied arguments.
- Keep write, delete, deploy, and payment tools explicitly gated regardless of how confident the calling agent appears.
- Log the rule that approved a call, not just that a call was approved — and log when the iteration cap ends a run, because that is the signal a model is looping on a tool.
- Approval policy is enforced per participant and per route: an agent whose chat client routes per session (see [Agent Middleware and Routing](agent-middleware.md)) still runs one approval pipeline, so switching route does not widen what a tool call may do. A Magentic manager whose prompts were customized still cannot widen what a participant is allowed to call — do not treat an orchestration prompt as a security control.

## ✅ Review checklist

- Every auto-approval rule has a test for the deny path.
- The auto-approval cap is explicit where the rules are broad, and the surfaced-request path after the cap is handled.
- File-access scopes are least-privilege and asserted in tests.
- Skill sources are disposed on the same lifecycle as the agent that owns them, with `ownsSource` set deliberately.

---
*Verified against MAF v1.20.0 DLL surface (2026-09-03). The agent-skills, file-access, and tool-approval surfaces are byte-identical from v1.18 through v1.20 by mechanical diff. **Provenance:** the decorator sources, granular approval flags, the `ownsSource` constructor, `IDisposable` disposal and the `AgentFileStore` calls were compile-tested against pinned **1.13.0**; the contextual `ToolAutoApprovalRuleContext` rules against **1.14.0**; and `MaxAutoApprovalIterations` with its `const` default was compiled and read against **1.18.0 and 1.19.0** (value 40, CS0131 on assignment proving the `const`; see `scripts/compile-verified.txt`), failing against 1.17.0 with CS1061/CS0117. A `const` is not emitted by the dumper at all, so that one rests on the 1.19.0 execution rather than on byte-identity; the remaining v1.13/v1.14 claims rest on their own compiles. Consolidated into this folder on 2026-09-01 from the v1.13, v1.14 and v1.18 guides; the pre-1.13 rename tables were deliberately left in their own folders and the version map, because they name shapes absent from this version's surface. No claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout` (documented and executed on the [Background Agents](background-agents.md) page), so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
