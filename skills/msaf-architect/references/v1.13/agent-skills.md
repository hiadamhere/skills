# 🧩 Agent Skills Sources & Provider (v1.13 — composable & disposable)

The agent-skills system feeds reusable skill definitions (`AgentSkill`) into an agent's context via `AgentSkillsProvider` (an `AIContextProvider`). The system has been **context-aware since v1.12** — sources and filters receive an `AgentSkillsSourceContext` identifying the requesting agent and session. **v1.13** builds on that with four changes:

1. **Composable source decorators** — wrap any `AgentSkillsSource` with caching, deduplication, filtering, or aggregation.
2. **Granular per-operation approval flags** on `AgentSkillsProviderOptions` and `FileAccessProviderOptions`.
3. **Disposable lifecycle** — `AgentSkillsSource`, `AgentSkillsProvider`, and `FileAccessProvider` are now `IDisposable`.
4. **Renamed `AgentFileStore` contract** — the file-store methods dropped the File infix and directory listing was consolidated (**breaking**).

> [!WARNING]
> This entire API family is marked **experimental** — compiling against it raises diagnostic **`MAAI001`**. Suppress it deliberately: `<NoWarn>$(NoWarn);MAAI001</NoWarn>` or `#pragma warning disable MAAI001`.

---

## 🏛️ Core Types (v1.13 shapes)

* **`AgentSkillsSourceContext`** — `AgentSkillsSourceContext(AIAgent agent, AgentSession session)`; exposes `AIAgent Agent { get; }` and `AgentSession Session { get; }`.
* **`AgentSkillsSource`** (abstract, now `IDisposable`) — override `Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken cancellationToken)`; override the virtual `Dispose()` to release handles.
* **`AgentSkillsProvider`** (now `IDisposable`) — the source-based constructor gained a `bool ownsSource` parameter: `AgentSkillsProvider(AgentSkillsSource source, AgentSkillsProviderOptions options, ILoggerFactory loggerFactory, bool ownsSource)`. The `skillPath(s)`, `AgentSkill[]`, and `IEnumerable<AgentSkill>` constructors are unchanged.
* **`AgentSkillsProviderBuilder`** — context-aware `UseFilter(Func<AgentSkill, AgentSkillsSourceContext, bool>)`, factory `UseSource(Func<ILoggerFactory, AgentSkillsSource>)`, `DisableCaching()`, `UseCachingOptions(Action<CachingAgentSkillsSourceOptions>)`, plus the carried-over `UseFileSkill(s)`, `UseSkill(s)`, `UsePromptTemplate`, `UseFileScriptRunner`, `UseLoggerFactory`, `UseOptions`, `Build()`.
* **`AgentFileSkillsSource`** — file-based source: `(string skillPath | IEnumerable<string> skillPaths, AgentFileSkillScriptRunner scriptRunner, AgentFileSkillsSourceOptions options, ILoggerFactory loggerFactory)`.
* **`CachingAgentSkillsSourceOptions`** — `Func<AgentSkillsSourceContext, string> CacheIsolationKeySelector` (partition the cache per agent/session) and, **new in v1.13**, `Nullable<TimeSpan> RefreshInterval` (re-pull skills after the interval elapses).
* **`AgentSkillsProviderOptions`** — `bool IncludeDetailedErrors`, `string SkillsInstructionPrompt`, and, **new in v1.13**, the granular approval flags `DisableLoadSkillApproval`, `DisableReadSkillResourceApproval`, `DisableRunSkillScriptApproval`.

## 🧬 Composable Skill Sources *(new in v1.13)*

v1.13 adds a decorator family over `AgentSkillsSource`. `DelegatingAgentSkillsSource` is the abstract base that forwards to an inner source; the concrete decorators wrap any source (including your own):

| Decorator | Constructor | Purpose |
|---|---|---|
| `CachingAgentSkillsSource` | `(AgentSkillsSource innerSource, CachingAgentSkillsSourceOptions options)` | Cache skills, optionally per agent/session and with a `RefreshInterval`. |
| `DeduplicatingAgentSkillsSource` | `(AgentSkillsSource innerSource, ILoggerFactory loggerFactory)` | Drop duplicate skills. |
| `FilteringAgentSkillsSource` | `(AgentSkillsSource innerSource, Func<AgentSkill, AgentSkillsSourceContext, bool> predicate, ILoggerFactory loggerFactory)` | Keep only skills matching a context-aware predicate. |
| `AggregatingAgentSkillsSource` | `(IEnumerable<AgentSkillsSource> sources)` | Merge several sources into one. |
| `AgentInMemorySkillsSource` | `(IEnumerable<AgentSkill> skills)` | Serve a fixed in-memory skill list. |

The builder's `UseFilter` / `UseCachingOptions` wire the equivalent decorators for you; construct them directly when you need explicit ordering.

## 🔐 Approval Control

Two complementary mechanisms gate tool calls:

**1. Auto-approval rules** (from v1.12) — pre-approve calls with a `Func<FunctionCallContent, ValueTask<bool>>` wired via `ToolApprovalAgentOptions.AutoApprovalRules`. Built-ins: `AgentSkillsProvider.AllToolsAutoApprovalRule` / `AgentSkillsProvider.ReadOnlyToolsAutoApprovalRule`, `FileAccessProvider.AllToolsAutoApprovalRule` / `FileAccessProvider.ReadOnlyToolsAutoApprovalRule`, `ToolApprovalAgent.AllToolsAutoApprovalRule`.

**2. Granular approval flags** *(new in v1.13)* — suppress the approval prompt for whole operation classes:
* `AgentSkillsProviderOptions`: `DisableLoadSkillApproval`, `DisableReadSkillResourceApproval`, `DisableRunSkillScriptApproval`.
* `FileAccessProviderOptions`: `DisableWriteTools`, `DisableReadOnlyToolApproval`, `DisableWriteToolApproval`.

## ♻️ Lifecycle, Disposal & Composition *(new in v1.13)*

`AgentSkillsSource`, `AgentSkillsProvider`, and `FileAccessProvider` implement `IDisposable`. Wrap the provider in `using` and pass `ownsSource: true` so it disposes the (composed) source it wraps:

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

// A custom source. AgentSkillsSource is IDisposable in v1.13 — override Dispose() to release handles.
public sealed class DbSkillsSource : AgentSkillsSource
{
    public override Task<IList<AgentSkill>> GetSkillsAsync(AgentSkillsSourceContext context, CancellationToken ct)
        => LoadSkillsForAgentAsync(context.Agent.Id, ct);
}

// ... elsewhere:
ILoggerFactory lf = NullLoggerFactory.Instance;
AgentSkillsSource source = new DbSkillsSource();

// Compose decorators (new in v1.13): filter -> dedupe -> cache.
AgentSkillsSource filtered = new FilteringAgentSkillsSource(
    source,
    (AgentSkill s, AgentSkillsSourceContext ctx) => s.Frontmatter.Name != "dangerous",
    lf);
AgentSkillsSource deduped = new DeduplicatingAgentSkillsSource(filtered, lf);
AgentSkillsSource cached = new CachingAgentSkillsSource(deduped, new CachingAgentSkillsSourceOptions
{
    RefreshInterval = TimeSpan.FromMinutes(5),          // re-pull skills every 5 min (new in v1.13)
    CacheIsolationKeySelector = ctx => ctx.Agent.Id,
});

// Provider is IDisposable; ownsSource:true disposes 'cached' when the provider is disposed.
using var provider = new AgentSkillsProvider(
    cached,
    new AgentSkillsProviderOptions
    {
        IncludeDetailedErrors = true,
        DisableLoadSkillApproval = true,                // granular approval flags (new in v1.13)
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
    .UseOptions(o => o.DisableRunSkillScriptApproval = true)
    .Build();
```

## 🗂️ `AgentFileStore` Contract Rename *(breaking in v1.13)*

`AgentFileStore` (implemented by the built-in `FileSystemAgentFileStore` and `InMemoryAgentFileStore`, and consumed by `FileAccessProvider`) dropped the File infix and consolidated directory listing. The calls below are compile-verified against `InMemoryAgentFileStore`:

```csharp
using Microsoft.Agents.AI;

// Built-in store; the same contract is implemented by FileSystemAgentFileStore.
AgentFileStore store = new InMemoryAgentFileStore();

await store.WriteAsync("notes/todo.txt", "buy milk", ct);
string text = await store.ReadAsync("notes/todo.txt", ct);
bool exists = await store.FileExistsAsync("notes/todo.txt", ct);

// ListChildrenAsync replaces the old ListFilesAsync + ListDirectoriesAsync pair.
IReadOnlyList<FileStoreEntry> children = await store.ListChildrenAsync("notes", ct);
foreach (FileStoreEntry entry in children)
    Console.WriteLine($"{entry.Name} ({entry.Type})");

IReadOnlyList<FileSearchResult> hits = await store.SearchAsync("notes", "milk", "*.txt", recursive: true, ct);

await store.DeleteAsync("notes/todo.txt", ct);
```

`ListChildrenAsync` returns `IReadOnlyList<FileStoreEntry>` (each entry carries `Name` and `Type`) instead of the bare path strings the old list methods returned, and `SearchAsync` renamed its `filePattern` argument to `globPattern`. v1.13 also adds the `FileLineEdit` type (`LineNumber`, `NewLine`) used by line-oriented file-edit tools.

## ⬆️ Migration from v1.12 (compile-verified breaking changes)

| v1.12 (removed/changed) | v1.13 (replacement) | Symptom if unmigrated |
|---|---|---|
| `new AgentSkillsProvider(source, options, loggerFactory)` | `new AgentSkillsProvider(source, options, loggerFactory, ownsSource)` | CS7036 (missing `ownsSource`) |
| `store.WriteFileAsync` / `store.ReadFileAsync` / `store.DeleteFileAsync` | `store.WriteAsync` / `store.ReadAsync` / `store.DeleteAsync` | CS1061 | <!-- v1.12 -->
| `store.ListFilesAsync` + `store.ListDirectoriesAsync` (→ `IReadOnlyList<string>`) | `store.ListChildrenAsync` (→ `IReadOnlyList<FileStoreEntry>`) | CS1061 | <!-- v1.12 -->
| `store.SearchFilesAsync(dir, regex, filePattern, recursive, ct)` | `store.SearchAsync(dir, regex, globPattern, recursive, ct)` | CS1061 | <!-- v1.12 -->
| `FileListEntry.FileName` | `FileListEntry.Name` (plus new `Type`) | CS1061 | <!-- v1.12 -->

Adopting `IDisposable` is source-compatible — existing code keeps working — but wrap providers in `using` (and set `ownsSource`) to avoid leaking source handles.

## Earlier migrations

The v1.11 → v1.12 context-awareness break (source/filter signatures gaining `AgentSkillsSourceContext`; `UseScriptApproval(bool)` replaced by `DisableCaching()` / `UseCachingOptions(...)`) is documented in [`v1.12/agent-skills.md`](../v1.12/agent-skills.md). <!-- v1.11 -->

---
*Verified against MAF v1.13.0 DLL surface (2026-07-07). Every v1.13 API usage pattern shown — the decorator sources, granular approval flags, the `ownsSource` constructor, `IDisposable` disposal, and the renamed `AgentFileStore` calls — was compile-tested against the pinned 1.13.0 packages; the v1.12 → v1.13 removals were confirmed by mechanical surface diff.*
