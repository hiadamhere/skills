# 🧠 AI Agent Skills Catalog

A curated collection of master-level agent skills, guidelines, and reference materials for Google Antigravity, Claude Code, OpenAI Codex, Aider, and Cline.

🌐 **Browse the interactive catalog page: [hiadamhere.github.io/skills](https://hiadamhere.github.io/skills/)** — explore the MSAF Architect skill visually, right in your browser.

---

## 📂 Available Skills

### 🏛️ `msaf-architect` (Microsoft Agent Framework C# Architect)
Master architecture guidelines, execution models, and API mappings for building multi-agent systems using the Microsoft Agent Framework.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> Tutorials and LLM training data describe Microsoft Agent Framework APIs that **were never shipped** (e.g. a `WorkflowSuspendedException` suspend pattern) and cause compiler failures.
>
> Every claim in this skill is **verified against the actual v1.10.0 through v1.19.0 assemblies from NuGet** — reflection surface extraction plus compile tests against the pinned packages. Reference documents carry per-version verification stamps, and an automated gate rejects any unverified API identifier before release. The latest guidance targets **v1.19** — session-persisted chat-client routing and the hosted-workflow checkpoint controls (`WithCheckpointing`, `WorkflowAgentMetadata`, `WorkflowSessionCheckpointRecovery`) — on top of **v1.18** (concurrent tool invocation, a bounded auto-approval loop, the invocable-function bypass, background-session release) and the **v1.15–v1.17** Workflows additions (latest-checkpoint resolution, the `blockOnPendingRequest` streaming overload, Magentic prompt overrides).

Every release from v1.15 to v1.19 is **purely additive** by mechanical surface diff (v1.17 changes nothing at all) — v1.14 code compiles unchanged throughout — so the traps are in adoption, not migration: `MagenticPromptOverrides` properties are `init`-only, `GetLatestCheckpointAsync` and `WorkflowSessionCheckpointRecovery.CurrentCheckpoint` return a **nullable** `CheckpointInfo?`, `TryPrepare` accepts any well-formed checkpoint id without checking that it exists, `WithCheckpointing` hands a wrapped agent back **unchanged**, a workflow hosted with `AsAIAgent` must speak the chat protocol or its first run throws, and the experimental surface is a compile **error** until `MAAI001` is suppressed — a gate applied per *member*, so the v1.18 invocable-function bypass and the v1.19 routing client are gated while their siblings `AllowConcurrentInvocation`, `MaxAutoApprovalIterations`, `WithCheckpointing`, and `WorkflowAgentMetadata` are not.

It also covers the four shipped **orchestration builders** — sequential, concurrent, group chat, and handoff — reached through the `static` `AgentWorkflowBuilder` facade. Each carries a trap the reflected surface cannot show: `GroupChatWorkflowBuilder` has **no public constructor**, there are **two** handoff builder types (`HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder`) that both work, and `BuildConcurrent`'s aggregator reads as required but is optional — all three established by compile test.

It also covers **context compaction** — the shipped layer that keeps a long-running agent inside its context window, unchanged from v1.10 through v1.19. Strategies (sliding window, truncation, tool-result elision, summarisation, context-window budgeting) decide *what* to drop; triggers decide *when*; `CompactionProvider` attaches the pair to an agent. Its traps are of the same kind and established the same way: `CompactAsync` is not the override target (the abstract member is `protected`, so no reflection dump can show it), `ToolCallFormatter` reflects as settable but is `init`-only, and the `UseAIContextProviders` you reach for first takes a different provider type than the one you have.

And it maps the **workflow event stream** — all 21 types, identical from v1.11 to v1.19 — because streaming a run is how you observe it. The traps there are of the same character: `WorkflowOutputEvent` has to be the *last* `case` in a `switch` or it silently swallows the agent-response events that derive from it, and the Magentic events sit in their own namespace, so without a second `using` they read as "not in this version" rather than "not imported".

The skill also covers **declarative executors** — the attribute-driven shape for handling several message types — including the finding that `ReflectingExecutor<T>` is `[Obsolete]` in every documented version and that its suggested replacement relies on a source generator the package does not ship. Neither fact is visible in a reflection dump, because a dump lists members and not the attributes decorating a type; both came from compiler diagnostics, and the working shape was executed rather than merely compiled.

The interactive visualizer includes a dedicated **v1.14 Migration Map** showing the unchanged Workflows layer and the compile-verified agent-mode, message-injection, tool-approval, and approval-middleware replacements, plus a **v1.15 & v1.16 Additions** view covering latest-checkpoint resolution, the pending-request streaming choice, the seven Magentic prompt slots, and the `MAAI001` gate, and a **v1.18 & v1.19 Additions** view covering per-session chat-client routing, the hosted-workflow checkpoint controls, and which of the new members are experimental and which are not.

### 📱 `maui-engineer` (.NET MAUI Architect)
Version-aware **architecture and planning** guidance for .NET MAUI apps: the decisions to get right before writing feature code — target-platform and SDK/workload/package strategy, project layout, MVVM/DI, navigation, state and offline data, platform-abstraction boundaries, performance budgets, accessibility, and publish/signing constraints. It resolves the real SDK, target frameworks, workloads, and packages first, and requires platform/runtime evidence instead of treating one successful desktop build as cross-platform proof.

The navigation guidance covers choosing one primary model, deep links that survive a cold start, and the DI lifetimes behind the classic page/view-model leak. The performance guidance deliberately ships **no threshold numbers** — it covers what to budget and how to measure and hold it, because a budget that did not come from your own baseline on your own target hardware is decoration.

The bundled environment inspector produces a reviewable JSON snapshot of the project's toolchain. This is a methodology skill: API specifics and platform behavior are resolved from the target project and official Microsoft docs, not asserted from a pinned DLL surface.

### 🎨 `spectre-console` (Spectre.Console Terminal-UI Expert)
Verified, version-matched guidance for building rich .NET terminal UIs with [Spectre.Console](https://spectreconsole.net/): tables, panels, trees, markup & color, live displays (`Status`/`Progress`/`Live`), and interactive prompts — plus the terminal-gating discipline that keeps interactive features from hanging in CI or hosted contexts.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> Every type, method, and property is **verified against the actual Spectre.Console v0.57.2 assemblies** (`Spectre.Console`, `Spectre.Console.Ansi`, `Spectre.Console.Testing`) — reflection surface extraction plus compile tests against the pinned package. The same automated gate rejects any unverified API identifier before release.

### 🧩 `microsoft-extensions-ai` (Microsoft.Extensions.AI — .NET LLM abstractions)
Verified, version-matched guidance for [Microsoft.Extensions.AI](https://learn.microsoft.com/dotnet/ai/), .NET's unified LLM layer: `IChatClient` calls and streaming, `ChatOptions`, tool/function calling, structured output, embeddings, and the middleware/DI pipeline — so generated code targets the current GA API instead of renamed preview members.

It covers the two mistakes that fail silently rather than loudly: declaring `ChatOptions.Tools` without the `UseFunctionInvocation()` middleware that actually executes them, and middleware ordering — where the cache sits relative to function invocation decides whether a cache hit skips the entire tool loop.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> Every type, method, and property is **verified against the actual Microsoft.Extensions.AI v10.8.1 assemblies** (`Microsoft.Extensions.AI`, `Microsoft.Extensions.AI.Abstractions`) — reflection surface extraction plus compile tests against the pinned package. Training data mixes the old preview API with GA (e.g. the renamed `GetResponseAsync`); the same automated gate rejects any unverified API identifier before release.

### 🔌 `mcp-sdk` (Model Context Protocol SDKs)
Verified guidance for building **MCP servers** with the official SDKs in **C#, TypeScript, and Python**: defining tools, wiring the stdio transport, and standing up a minimal server with the correct, version-matched API. MCP postdates most training data, so models invent its shapes — this anchors them to the real SDK.

Each language carries a different trap, and each is compile- or type-checked here: in **Python**, `from mcp.server.fastmcp import FastMCP` — the import in nearly every MCP tutorial — **does not exist** in `mcp` 2.0.0 (the class is now `MCPServer`); in **TypeScript**, the widely-shown `server.tool()` is `@deprecated` in favour of `registerTool`, and import paths need `.js` suffixes; in **C#**, the `WithHttpTransport()` / `MapMcp()` wiring most samples show lives in a separate package and does not compile against the pinned one.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> All three language references are verified against their own pinned SDK: **C#** against the real `ModelContextProtocol` v2.0.0-preview.3 assemblies (reflection surface extraction + compile tests), **TypeScript** against `@modelcontextprotocol/sdk` 1.30.0 shipped type definitions (type-checked with `tsc --noEmit`), and **Python** against `mcp` 2.0.0 shipped type information (type-checked with `pyright`). The same automated gate rejects any unverified API identifier before release.

### 🔍 `reviewers` (configurable review panel)
A **review panel** rather than a single reviewer: several independent lenses examine the same change in parallel, each answering one question well instead of one reviewer answering all of them adequately. Findings merge by severity; verdicts roll up **worst-case-wins**, so a single blocking lens outranks every approval — deliberately, because averaging dilutes the one specialist who saw what nobody else was looking for.

**It is not a code reviewer — it is a way to run *your* rules as reviewers.** The shipped pack is a starter kit: eight generic code-review lenses, organised by *who pays when a change is wrong* — **correctness**, **evidence**, **risk**, **clarity** on every change; **security**, **performance**, **interface**, **docs** when the change touches their surface. They show the shape of a lens and say roughly what any careful reviewer would. The panel earns its cost when you add lenses that encode the mistakes your project has actually made: this catalog runs eight of its own — phantom-API hunting, twin-document drift, public-artifact truth, release registration — and those are the lenses that find things. Declare read-only `facts` (your gate, your tests) and the adapter runs them once for every lens instead of each lens re-running them; pick the `quick` profile for a small edit or `--all` before a release.

> [!IMPORTANT]
> **Built to be customized, and to survive updates.** Shipped files are replaced on every update; your overlay in `reviewers.local/` is never touched. Disable a lens, retune when it fires, replace one wholesale, or add your own — a lens is a markdown file plus a roster entry, with no code anywhere. Point `lessons` at your own post-mortems and every lens reads them *before* hunting new findings, so a defect you already paid for is not rediscovered from scratch. The panel reviews anything, not only code: the machinery makes no assumption about source code, only the default lenses do.

---

## 🚀 Installing the Skills

Three ways to install — pick whichever fits your setup.

### 1. With `spm` (recommended) — installs into every coding agent

**[`spm`](https://www.npmjs.com/package/@hiadamhere/spm)** (Skill & Plugin Manager) is a package manager for AI-agent skills. It installs this catalog into **all** your coding agents — Claude Code, Codex, Cursor, Cline, Aider, GitHub Copilot, and more — from the command line.

**Install `spm`** (choose one — no repo clone required):
```bash
npm install -g @hiadamhere/spm     # Node — self-contained, no .NET required
dotnet tool install -g spm          # …or the .NET global tool
```

**Install every skill from this catalog:**
```bash
spm install hiadamhere/skills
```
> Don't want a global install? Run it once with npx: `npx @hiadamhere/spm install hiadamhere/skills`

**Or subscribe to the catalog** to keep it updated and install skills by name:
```bash
spm catalog add hiadamhere https://github.com/hiadamhere/skills.git
spm catalog sync
spm list                      # browse available skills
spm search table              # find one
spm install spectre-console   # install a single skill
spm install maui-engineer     # install the MAUI architect
spm uninstall spectre-console # remove it
```

### 2. One-line remote install — no package manager needed

No Node or .NET? A self-contained script deploys all catalog skills to your user-level agent config folders (`~/.agents/skills` for Codex/Gemini, `~/.claude/skills` for Claude Code):

#### On Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex
```

#### On macOS/Linux (Bash):
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash
```

### 3. Local / workspace install (clone) — copy or symlink, per-skill, custom scope

Clone the repo and run the installer with flags for finer control:

*   **Mode:** Copy files or Symlink (recommended for automatic updates via `git pull`).
*   **Scope:** **Global** (user-profile) or **Folder** (workspace-level — copies into `<folder>/.agents/skills/` and `<folder>/.claude/skills/`).
*   **Skills:** Multi-select specific skills; interactive runs present a menu with `ALL` as the first choice.

#### Windows (PowerShell):
```powershell
# Interactive (prompts for mode, scope, target folder, and skills)
.\install.ps1
# Non-interactive copy of specific skills to a workspace
.\install.ps1 -Mode Copy -Scope Folder -Path C:\MyProject -Skills msaf-architect
# Uninstall
.\uninstall.ps1 -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

#### macOS/Linux (Bash):
```bash
# Interactive
./install.sh
# Non-interactive symlink of specific skills to a workspace
./install.sh --mode link --scope folder --path /path/to/my-project --skills msaf-architect
# Uninstall
./uninstall.sh --scope folder --path /path/to/my-project --skills msaf-architect
```

---
Distributed under the MIT License.
